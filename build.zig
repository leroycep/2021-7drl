const std = @import("std");
const Builder = std.build.Builder;
const deps = @import("./deps.zig");

const PLATFORM = std.build.Pkg{
    .name = "platform",
    .path = "platform/platform.zig",
    .dependencies = &[_]std.build.Pkg{ deps.pkgs.math, deps.pkgs.zigimg },
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const native = b.addExecutable("2021-7drl", "src/main.zig");
    native.setTarget(target);
    native.setBuildMode(mode);
    native.install();
    native.linkLibC();
    native.linkSystemLibrary("SDL2");
    native.addPackage(PLATFORM);
    native.addPackage(deps.pkgs.zigimg);
    native.addPackage(deps.pkgs.math);
    b.step("native", "Build native binary").dependOn(&native.step);

    const wasm = b.addStaticLibrary("2021-7drl-web", "src/main.zig");
    wasm.setBuildMode(mode);
    wasm.setOutputDir(b.fmt("{s}/www", .{b.install_prefix}));
    wasm.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    wasm.addPackage(PLATFORM);
    wasm.addPackage(deps.pkgs.zigimg);
    wasm.addPackage(deps.pkgs.math);

    const static = b.addInstallDirectory(.{
        .source_dir = "static",
        .install_dir = .Prefix,
        .install_subdir = "www",
    });

    const build_wasm = b.step("wasm", "Build WASM application");
    build_wasm.dependOn(&wasm.step);
    build_wasm.dependOn(&static.step);

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
