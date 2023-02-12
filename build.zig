const std = @import("std");
const fs = std.fs;
const CrossTarget = std.build.CrossTarget;
const Target = std.Target;
const Step = std.Build.Step;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    // const target = b.standardTargetOptions(.{});
    const target = .{
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
    // exe.strip = true;
    exe.setLinkerScriptPath(.{ .path = "src/link.ld" });

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    exe.install();
    // This *creates* a RunStep in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = exe.run();

    // By making the run step depend on the install step, it will be run from the
    // installation directory rather than directly from within the cache directory.
    // This is not necessary, however, if the application depends on other installed
    // files, this ensures they will be present and in the expected location.
    run_cmd.step.dependOn(b.getInstallStep());

    // This allows the user to pass arguments to the application in the build
    // command itself, like this: `zig build run -- arg1 arg2 etc`
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    //zig objcopy-O binary zig-out/bin/zkernel kernel.bin
    const exe_path = b.getInstallPath(exe.install_step.?.dest_dir, exe.out_filename);
    const bin = b.addSystemCommand(&.{ "zig", "objcopy", "-O", "binary", exe_path, "kernel.bin" });
    const bin_step = b.step("bin", "create .bin");
    bin_step.dependOn(&bin.step);

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
    run_step.dependOn(&bin.step);
    build_boot(b, &bin.step);

    // Creates a step for unit testing.
    const exe_tests = b.addTest(.{
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&exe_tests.step);
}

fn build_boot(b: *std.Build, bin_step: *Step) void {
    const compile_boot_sect = b.addSystemCommand(&.{
        "nasm",
        "-f",
        "bin",
        "boot/boot_sect_simple.asm",
        "-o",
        "boot_sect_simple.bin",
    });

    const link = BootLinkStep.create(b, "link bootloader and kernel", &.{ "boot_sect_simple.bin", "kernel.bin" }, "os-image.bin");
    const run_qemu = b.addSystemCommand(&.{
        "qemu-system-i386",
        "-fda",
        "os-image.bin",
    });

    const build_boot_step = b.step("qemu", "run kernel in qemu");
    build_boot_step.dependOn(b.getInstallStep());
    build_boot_step.dependOn(bin_step);
    build_boot_step.dependOn(&compile_boot_sect.step);
    build_boot_step.dependOn(&link.step);
    build_boot_step.dependOn(&run_qemu.step);
}

const BootLinkStep = struct {
    step: Step,
    in_files: []const []const u8,
    out_file: []const u8,

    fn create(b: *std.Build, name: []const u8, in_files: []const []const u8, out_file: []const u8) *BootLinkStep {
        const self = b.allocator.create(@This()) catch @panic("error");
        self.* = .{ .step = Step.init(.custom, name, b.allocator, make), .in_files = in_files, .out_file = out_file };
        return self;
    }

    fn make(step: *Step) !void {
        const self = @fieldParentPtr(@This(), "step", step);
        var f_out = try fs.cwd().createFile(self.out_file, .{});
        defer f_out.close();
        for (self.in_files) |file| {
            var f_in = try fs.cwd().openFile(file, .{});
            defer f_in.close();
            try f_out.writeFileAll(f_in, .{});
        }
    }
};
