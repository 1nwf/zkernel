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
    exe.strip = true;
    exe.code_model = .kernel;
    exe.setLinkerScriptPath(.{ .path = "src/link.ld" });

    const nasm_sources = [_][]const u8{
        "src/entry.asm",
    };

    const nasm_out = compileNasmSource(b, &nasm_sources);

    for (nasm_out) |out| {
        exe.addObjectFileSource(.{ .path = out });
    }

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    std.Build.installArtifact(b, exe);
    // exe.install();

    const bin = exe.addObjCopy(.{ .basename = "kernel.bin", .format = .bin });
    const install_step = b.addInstallBinFile(bin.getOutputSource(), bin.basename);
    b.default_step.dependOn(&install_step.step);
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
