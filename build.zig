const std = @import("std");
const ArrayList = std.ArrayList;
const Build = std.Build;

const AssetEntry = struct { []const u8, []const u8 };

pub fn addAssets(b: *std.Build, exe: *std.Build.Step.Compile) !void {
    const allocator = b.allocator;
    const dir_path = "./svelte/build";

    var dir = try std.fs.cwd().openDir(dir_path, .{ .iterate = true });
    defer dir.close();

    var walker = try dir.walk(allocator);
    defer walker.deinit();

    var paths = ArrayList(AssetEntry).init(allocator);
    defer paths.deinit(); // We'll return the inner slice, so this is safe

    while (try walker.next()) |entry| {
        if (entry.kind == .file) {
            const full_path = try std.fs.path.join(allocator, &[_][]const u8{dir_path, entry.path});
            var name = std.fs.path.stem(entry.path);
            // std.debug.print("Found file: {s}\n", .{std.fs.path.file_name(entry.path)});

            const dot_index = std.mem.lastIndexOf(u8, full_path, &[_]u8{'.'});

            const valid_index: usize = dot_index orelse full_path.len;
            
            if (dot_index) |index| {
                const extension = full_path[index..];
                // const total_length = name.len + extension.len + 1; // +1 for null terminator

                const tes = try std.fmt.allocPrint(allocator, "{s}{s}", .{name, extension});
                // defer allocator.free(tes);
                name = tes;

                std.debug.print("{s}\n", .{full_path});
            } else {
                std.debug.print("No extension found. Using fallback index: {}\n", .{valid_index});
            }

            const asset_entry = AssetEntry{ full_path, try allocator.dupe(u8, name) };
            try paths.append(asset_entry);
        }
    }
    
    const asset_entries = try paths.toOwnedSlice();
    defer {
        for (asset_entries) |entry| {
            allocator.free(entry[0]);
            allocator.free(entry[1]);
        }
        allocator.free(asset_entries);
    }

    for (asset_entries) |entry| {
        const path = entry[0];
        const name = entry[1];
        exe.root_module.addAnonymousImport(name, .{ .root_source_file = b.path(path) });
    }

}

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
pub fn build(b: *std.Build) void {
    // Standard target options allows the person running `zig build` to choose
    // what target to build for. Here we do not override the defaults, which
    // means any target is allowed, and the default is native. Other options
    // for restricting supported target set are available.
    const target = b.standardTargetOptions(.{});

    // Standard optimization options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall. Here we do not
    // set a preferred release mode, allowing the user to decide how to optimize.
    const optimize = b.standardOptimizeOption(.{});

    // const lib = b.addStaticLibrary(.{
    //     .name = "zig-svelte",
    //     // In this case the main source file is merely a path, however, in more
    //     // complicated build scripts, this could be a generated file.
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // // This declares intent for the library to be installed into the standard
    // // location when the user invokes the "install" step (the default step when
    // // running `zig build`).
    // b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "zig-svelte",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    addAssets(b, exe) catch |err| {
        std.debug.print("Error adding assets: {}\n", .{err});
        return;
    };

    // This declares intent for the executable to be installed into the
    // standard location when the user invokes the "install" step (the default
    // step when running `zig build`).
    b.installArtifact(exe);

    // This *creates* a Run step in the build graph, to be executed when another
    // step is evaluated that depends on it. The next line below will establish
    // such a dependency.
    const run_cmd = b.addRunArtifact(exe);

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

    // This creates a build step. It will be visible in the `zig build --help` menu,
    // and can be selected like this: `zig build run`
    // This will evaluate the `run` step rather than the default, which is "install".
    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    // Creates a step for unit testing. This only builds the test executable
    // but does not run it.
    // const lib_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/root.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_lib_unit_tests = b.addRunArtifact(lib_unit_tests);

    // const exe_unit_tests = b.addTest(.{
    //     .root_source_file = b.path("src/main.zig"),
    //     .target = target,
    //     .optimize = optimize,
    // });

    // const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    // Similar to creating the run step earlier, this exposes a `test` step to
    // the `zig build --help` menu, providing a way for the user to request
    // running the unit tests.
    // const test_step = b.step("test", "Run unit tests");
    // test_step.dependOn(&run_lib_unit_tests.step);
    // test_step.dependOn(&run_exe_unit_tests.step);

    // libraries
    const httpz = b.dependency("httpz", .{
        .target = target,
        .optimize = optimize,
    });

    // the executable from your call to b.addExecutable(...)
    exe.root_module.addImport("httpz", httpz.module("httpz"));
}
