const std = @import("std");
const fs = std.fs;
const Target = std.Target;
const Step = std.Build.Step;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) !void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    // const target = b.standardTargetOptions(.{});
    const target: std.zig.CrossTarget = .{
        .cpu_arch = .x86,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .ofmt = .elf,
        .cpu_model = .{ .explicit = &Target.x86.cpu.i386 },
    };

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    // const optimize = b.standardOptimizeOption(.{});
    const optimize = .ReleaseSafe;

    const exe = b.addExecutable(.{
        .name = "zkernel",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
        .linkage = .static,
    });
    exe.strip = false;
    exe.setLinkerScriptPath(.{ .path = "src/link.ld" });

    const nasm_sources = [_][]const u8{
        "src/entry.asm",
    };

    const nasm_out = compileNasmSource(b, &nasm_sources);

    const arch = b.addModule("arch", .{
        .source_file = .{
            .path = "src/arch.zig",
        },
    });
    exe.addModule("arch", arch);

    for (nasm_out) |out| {
        exe.addObjectFile(.{ .path = out });
    }

    addUserspacePrograms(b, exe);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    std.Build.installArtifact(b, exe);
    // exe.install();

    const bin = exe.addObjCopy(.{ .basename = "kernel.bin", .format = .bin });
    const install_step = b.addInstallBinFile(bin.getOutputSource(), bin.basename);
    b.default_step.dependOn(&install_step.step);

    const unit_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/tests.zig" },
        .target = b.standardTargetOptions(.{}),
        .optimize = optimize,
    });
    unit_tests.addModule("arch", arch);

    const run_unit_tests = b.addRunArtifact(unit_tests);

    const arch_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/arch.zig" },
        .optimize = optimize,
    });
    const run_arch_tests = b.addRunArtifact(arch_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_unit_tests.step);
    test_step.dependOn(&run_arch_tests.step);

    const kernel_bin = b.fmt("{s}/{s}", .{ b.exe_dir, exe.out_filename });
    const make_iso = GrubBuildStep.init(b, kernel_bin);

    const kernel_iso = "iso/os.iso";

    const nodisplay = b.option(bool, "no-display", "disable qemu display") orelse false;
    const run_qemu = RunQemuStep.init(b, kernel_iso, nodisplay, &.{ "--serial", "stdio" });
    const run_qemu_monitor = RunQemuStep.init(b, kernel_iso, nodisplay, &.{ "-d", "guest_errors", "-no-reboot", "-no-shutdown", "-monitor", "stdio" });
    const run_qemu_debug = RunQemuStep.init(b, kernel_iso, nodisplay, &.{ "-s", "-S" });

    run_qemu.step.dependOn(&make_iso.step);
    run_qemu_monitor.step.dependOn(&make_iso.step);
    run_qemu_debug.step.dependOn(&make_iso.step);

    const monitor = b.step("monitor", "runs os with qemu monitor");
    monitor.dependOn(run_qemu_monitor.step);

    const debug = b.step("debug", "run qemu in debug mode");
    debug.dependOn(run_qemu_debug.step);

    const run = b.step("run", "run kernel in qemu");
    run.dependOn(run_qemu.step);
}

fn replaceExtension(b: *std.Build, path: []const u8, new_extension: []const u8) []const u8 {
    const basename = std.fs.path.basename(path);
    const ext = std.fs.path.extension(basename);
    return b.fmt("{s}{s}", .{ basename[0 .. basename.len - ext.len], new_extension });
}

fn compileNasmSource(b: *std.Build, comptime nasm_sources: []const []const u8) [nasm_sources.len][]const u8 {
    const compile_step = b.step("nasm", "compile nasm source");

    var outputSources: [nasm_sources.len][]const u8 = undefined;
    for (nasm_sources, 0..) |src, idx| {
        const out = replaceExtension(b, src, ".o");
        const create_bin = b.addSystemCommand(&.{ "nasm", "-f", "elf32", src, "-o", out });
        outputSources[idx] = out;

        compile_step.dependOn(&create_bin.step);
    }

    b.default_step.dependOn(compile_step);
    return outputSources;
}

const GrubBuildStep = struct {
    b: *std.Build,
    step: std.Build.Step,
    exe_bin: []const u8,
    exe_dir: []const u8,

    fn init(b: *std.Build, exe_bin: []const u8) *GrubBuildStep {
        var gbstep = b.allocator.create(@This()) catch unreachable;
        gbstep.* = .{
            .exe_dir = b.exe_dir,
            .exe_bin = exe_bin,
            .step = std.Build.Step.init(.{
                .id = .custom,
                .name = "build grub image",
                .makeFn = GrubBuildStep.makeFn,
                .owner = b,
            }),
            .b = b,
        };

        gbstep.step.dependOn(b.default_step);
        return gbstep;
    }

    fn makeFn(step: *std.Build.Step, _: *std.Progress.Node) anyerror!void {
        const self = @fieldParentPtr(@This(), "step", step);
        const exe_dir = try std.fs.openDirAbsolute(self.exe_dir, .{});
        const iso_dir = try std.fs.cwd().openDir("iso/boot", .{});
        std.fs.cwd().deleteFile("iso/os.iso") catch |e| {
            switch (e) {
                error.FileNotFound => {},
                else => return e,
            }
        };
        try std.fs.Dir.copyFile(exe_dir, self.exe_bin, iso_dir, "kernel.elf", .{});
        try self.build_iso_img();
    }

    fn build_iso_img(self: *@This()) !void {
        var child = std.ChildProcess.init(
            &.{
                "grub-mkrescue",
                "-o",
                "iso/os.iso",
                "iso/",
            },
            self.b.allocator,
        );

        child.stdin_behavior = .Ignore;
        child.stdout_behavior = .Ignore;
        child.stderr_behavior = .Ignore;
        child.env_map = self.b.env_map;

        switch (try child.spawnAndWait()) {
            .Exited => |code| {
                if (code != 0) {
                    return error.ExitCodeFailure;
                }
            },
            .Signal, .Stopped, .Unknown => |_| {
                return error.ProcessTerminated;
            },
        }
    }
};

const RunQemuStep = struct {
    step: *std.Build.Step,
    b: *std.Build,

    const Self = @This();
    fn init(b: *std.Build, iso_path: []const u8, nodisplay: bool, options: ?[]const []const u8) Self {
        var sys_cmd = b.addSystemCommand(&.{ "qemu-system-i386", "-boot", "d", "-cdrom", iso_path, "-m", "128M", "-nic", "user,model=virtio" });
        sys_cmd.step.dependOn(b.default_step);
        if (nodisplay) {
            sys_cmd.addArgs(&.{ "--display", "none" });
        }
        if (options) |op| {
            sys_cmd.addArgs(op);
        }
        return .{
            .step = &sys_cmd.step,
            .b = b,
        };
    }
};

pub fn addUserspacePrograms(b: *std.Build, kernel_exe: *Step.Compile) void {
    const target: std.zig.CrossTarget = .{
        .cpu_arch = .x86,
        .os_tag = Target.Os.Tag.freestanding,
        .abi = Target.Abi.none,
        .ofmt = .elf,
        .cpu_model = .{ .explicit = &Target.x86.cpu.i386 },
    };

    const programs = [_][]const u8{"write"};
    const stdlib = b.addModule("stdlib", .{
        .source_file = .{ .path = "stdlib/stdlib.zig" },
    });

    for (programs) |p| {
        const source_file = b.fmt("userspace_programs/{s}/src/main.zig", .{p});
        const exe = b.addExecutable(.{
            .name = p,
            .root_source_file = .{ .path = source_file },
            .target = target,
            .optimize = .ReleaseSafe,
            .linkage = .static,
        });
        exe.addModule("stdlib", stdlib);
        std.Build.installArtifact(b, exe);
        kernel_exe.step.dependOn(&exe.step);
        kernel_exe.addAnonymousModule(b.fmt("userspace_programs/{s}.elf", .{p}), .{ .source_file = .{
            .path = b.fmt("{s}/{s}", .{ b.exe_dir, exe.out_filename }),
        } });
    }
}
