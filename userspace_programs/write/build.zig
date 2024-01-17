const std = @import("std");
const Target = std.Target;

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.

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
    const optimize: std.builtin.OptimizeMode = .ReleaseSafe;

    const exe = b.addExecutable(.{
        .name = "write",
        // In this case the main source file is merely a path, however, in more
        // complicated build scripts, this could be a generated file.
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });

    const stdlib = b.addModule("stdlib", .{
        .source_file = .{ .path = "../../stdlib/stdlib.zig" },
    });
    exe.addModule("stdlib", stdlib);

    const start = b.addObject(.{
        .name = "start",
        .root_source_file = .{ .path = "../../stdlib/start.zig" },
        .target = target,
        .optimize = optimize,
    });
    exe.addObject(start);

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);
}
