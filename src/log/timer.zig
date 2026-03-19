const zvm = @import("../root.zig");
const std = @import("std");

pub var global_timer: ?std.time.Timer = null;

pub fn start() !void {
    global_timer = try std.time.Timer.start();
}

pub fn read() u64 {
    return global_timer.?.read();
}
