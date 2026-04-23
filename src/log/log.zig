const zvm = @import("../root.zig");
const std = @import("std");

const grey = "\x1b[38;2;100;100;100m";
const cyan = "\x1b[38;2;100;200;255m";
const white = "\x1b[0m";
const green = "\x1b[38;2;100;255;100m";
const dim = "\x1b[38;2;140;140;140m";

pub fn debug(msg: []const u8, obj: anytype) void {
    const elapsed = zvm.timer.read();
    const ms_total = elapsed / std.time.ns_per_ms;
    const minutes = ms_total / 60000;
    const seconds = (ms_total % 60000) / 1000;
    const millis  = ms_total % 1000;
    const micros  = (elapsed % std.time.ns_per_ms) / std.time.ns_per_us;

    // Timestamp
    std.debug.print(grey ++ "[{d:0>2}:{d:0>2}:{d:0>3}:{d:0>3}]" ++ white ++ " {s}", .{ minutes, seconds, millis, micros, msg });

    // Inline object details
    switch (@TypeOf(obj)) {
        zvm.core.cpu.CPU => {
            std.debug.print("\n", .{});
            for (0..obj.gpr.len) |slot| {
                switch (@TypeOf(obj.gpr[slot])) {
                    zvm.core.reg.Reg8 => {
                        const v8: u8 = @bitCast(obj.gpr[slot].value);
                        std.debug.print(grey ++ "             | " ++ cyan ++ "{s}-{d:0>2}" ++ dim ++ " = " ++ white ++ "0x{X:0>2}\n", .{ obj.gpr[slot].name, slot, v8 });
                    },
                    zvm.core.reg.Reg32 => {
                        const v32: u32 = @bitCast(obj.gpr[slot].value);
                        std.debug.print(grey ++ "             | " ++ cyan ++ "{s}-{d:0>2}" ++ dim ++ " = " ++ white ++ "0x{X:0>8}\n", .{ obj.gpr[slot].name, slot, v32 });
                    },
                    else => {
                        std.debug.print(grey ++ "             | " ++ cyan ++ "{s}-{d:0>2}" ++ dim ++ " = " ++ white ++ "?\n", .{ obj.gpr[slot].name, slot });
                    },
                }
            }
        },
        *zvm.core.reg.Reg8, zvm.core.reg.Reg8 => {
            std.debug.print(" " ++ cyan ++ "{s}" ++ dim ++ "#{d}" ++ white ++ " = " ++ green ++ "0x{X:0>2}" ++ white ++ "\n", .{ obj.name, obj.id, @as(u8, @bitCast(obj.value)) });
        },
        *zvm.core.reg.Reg32, zvm.core.reg.Reg32 => {
            std.debug.print(" " ++ cyan ++ "{s}" ++ dim ++ "#{d}" ++ white ++ " = " ++ green ++ "0x{X:0>8}" ++ white ++ "\n", .{ obj.name, obj.id, @as(u32, @bitCast(obj.value)) });
        },
        zvm.device.device.Device, *zvm.device.device.Device => {
            std.debug.print(" " ++ cyan ++ "{s}" ++ white ++ "\n", .{obj.name});
        },
        zvm.mem.bus.Region, *zvm.mem.bus.Region => {
            std.debug.print(" " ++ cyan ++ "{s}" ++ dim ++ " @ " ++ white ++ "0x{X:0>7}..0x{X:0>7}" ++ dim ++ " ({d} bytes)" ++ white ++ "\n", .{ obj.device.name, obj.base, obj.base + obj.size - 1, obj.size });
        },
        u8, u16, u32, u64, comptime_int => {
            std.debug.print(" " ++ green ++ "{d}" ++ white ++ "\n", .{obj});
        },
        else => {
            std.debug.print("\n", .{});
        },
    }
}
