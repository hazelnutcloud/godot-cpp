const std = @import("std");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    std.fs.cwd().access("gen", .{}) catch |e| {
        switch (e) {
            error.FileNotFound => {
                _ = try std.ChildProcess.run(.{ .allocator = b.allocator, .argv = &.{ "python", "binding_generator.py" } });
            },
            else => {
                return;
            },
        }
    };

    const lib_godot = b.addStaticLibrary(.{
        .name = "libgodot",
        .target = target,
        .optimize = optimize,
    });
    lib_godot.linkLibCpp();

    lib_godot.addIncludePath(.{ .path = "gdextension/" });
    lib_godot.addIncludePath(.{ .path = "include/" });
    lib_godot.addIncludePath(.{ .path = "gen/include" });

    const flags = [_][]const u8{ "-std=c++17", "-fno-exceptions" };
    try addCSourceRecursive(b, lib_godot, "src", &flags);
    try addCSourceRecursive(b, lib_godot, "gen/src", &flags);

    b.installArtifact(lib_godot);
}

fn addCSourceRecursive(b: *std.Build, obj: *std.Build.Step.Compile, dir_name: []const u8, flags: []const []const u8) !void {
    var sources = std.ArrayList([]const u8).init(b.allocator);

    var dir = try std.fs.cwd().openDir(dir_name, .{ .iterate = true });
    var walker = try dir.walk(b.allocator);
    defer walker.deinit();

    const allowed_exts = [_][]const u8{ ".c", ".cpp", ".cxx", ".c++", ".cc" };
    while (try walker.next()) |entry| {
        const ext = std.fs.path.extension(entry.basename);
        const include_file = for (allowed_exts) |e| {
            if (std.mem.eql(u8, ext, e)) {
                break true;
            }
        } else false;
        if (include_file) {
            try sources.append(b.fmt("{s}/{s}", .{ dir_name, entry.path }));
        }
    }

    obj.addCSourceFiles(.{ .files = sources.items, .flags = flags });
}
