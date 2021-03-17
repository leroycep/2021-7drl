const std = @import("std");
const Builder = std.build.Builder;
const deps = @import("./deps.zig");

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const native = b.addExecutable("2021-7drl", "src/main.zig");
    native.setTarget(target);
    native.setBuildMode(mode);
    native.install();
    native.linkLibC();
    native.linkSystemLibrary("SDL2");
    deps.addAllTo(native);
    b.step("native", "Build native binary").dependOn(&native.step);
    
    const native_run = native.run();
    // Start the program in the directory with the assets in it
    native_run.cwd = "static";
    
    const native_run_step = b.step("run", "Run the native binary");
    native_run_step.dependOn(&native_run.step);

    const web = b.addStaticLibrary("2021-7drl-web", "src/main.zig");
    web.setBuildMode(mode);
    web.setOutputDir(b.fmt("{s}/www", .{b.install_prefix}));
    web.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    deps.addAllTo(web);

    const static = b.addInstallDirectory(.{
        .source_dir = "static",
        .install_dir = .Prefix,
        .install_subdir = "www",
    });

    const build_web = b.step("web", "Build WASM application");
    build_web.dependOn(&web.step);
    build_web.dependOn(&static.step);

    var main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
