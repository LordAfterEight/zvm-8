const zvm = @import("../root.zig");
const std = @import("std");

const grey = "\x1b[38;2;100;100;100m";
const cyan = "\x1b[38;2;100;200;255m";
const white = "\x1b[0m";
const green = "\x1b[38;2;100;255;100m";
const dim = "\x1b[38;2;140;140;140m";
const yellow = "\x1b[38;2;255;200;80m";

fn timestamp() void {
    const elapsed = zvm.timer.read();
    const ms_total = elapsed / std.time.ns_per_ms;
    const minutes = ms_total / 60000;
    const seconds = (ms_total % 60000) / 1000;
    const millis = ms_total % 1000;
    const micros = (elapsed % std.time.ns_per_ms) / std.time.ns_per_us;
    std.debug.print(grey ++ "[{d:0>2}:{d:0>2}:{d:0>3}:{d:0>3}]" ++ white, .{ minutes, seconds, millis, micros });
}

/// Logs a single CPU instruction execution: address, mnemonic, and operand details.
pub fn trace(addr: u16, op: []const u8, detail: []const u8) void {
    timestamp();
    std.debug.print(" " ++ yellow ++ "0x{X:0>4}" ++ white ++ "  " ++ cyan ++ "{s}" ++ white, .{ addr, op });
    if (detail.len > 0) {
        std.debug.print("  " ++ dim ++ "{s}" ++ white, .{detail});
    }
    std.debug.print("\n", .{});
}

/// Logs a system-level event (reset, ROM load, device mapping, etc.)
pub fn info(msg: []const u8) void {
    timestamp();
    std.debug.print(" " ++ green ++ "{s}" ++ white ++ "\n", .{msg});
}
