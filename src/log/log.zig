const zvm = @import("../root.zig");
const std = @import("std");

pub fn debug(msg: []const u8, obj: anytype) void {
    std.debug.print("\x1b[38;2;100;100;100mmsg:\x1b[0m {s}\n", .{msg});
    switch (@TypeOf(obj)) {
        zvm.core.cpu.CPU => {
            std.debug.print("\x1b[38;2;0;255;0m * Registers:\x1b[0m\n", .{});
            for (0..obj.gpr.len) |slot| {
                switch (@TypeOf(obj.gpr[slot])) {
                    zvm.core.reg.Reg8 => {
                        const v8: u8 = @bitCast(obj.gpr[slot].value);
                        std.debug.print(
                            "\x1b[38;2;0;255;255m    - {s}-{d:02}: 0x{X:02}\x1b[0m\n",
                            .{ obj.gpr[slot].name, slot, v8 },
                        );
                    },
                    zvm.core.reg.Reg32 => {
                        const v32: u32 = @bitCast(obj.gpr[slot].value);
                        std.debug.print(
                            "\x1b[38;2;0;255;255m    - {s}-{d:02}: 0x{X:08}\x1b[0m\n",
                            .{ obj.gpr[slot].name, slot, v32 },
                        );
                    },
                    else => {
                        std.debug.print(
                            "\x1b[38;2;255;0;0m    - {s}-{d:02}: <unsupported width>\x1b[0m\n",
                            .{ obj.gpr[slot].name, slot },
                        );
                    },
                }
            }
        },
        *zvm.core.reg.Reg8, zvm.core.reg.Reg8 => {
            std.debug.print(" \x1b[38;2;0;255;255m* Name: {s}\x1b[0m\n", .{obj.name});
            std.debug.print(" \x1b[38;2;0;255;255m* ID: {d}\x1b[0m\n", .{obj.id});
            std.debug.print(" \x1b[38;2;0;255;255m* Value: {d}\x1b[0m\n", .{@as(u8, @bitCast(obj.value))});
        },
        *zvm.core.reg.Reg32, zvm.core.reg.Reg32 => {
            std.debug.print(" \x1b[38;2;0;255;255m* Name: {s}\x1b[0m\n", .{obj.name});
            std.debug.print(" \x1b[38;2;0;255;255m* ID: {d}\x1b[0m\n", .{obj.id});
            std.debug.print(" \x1b[38;2;0;255;255m* Value: {d}\x1b[0m\n", .{@as(u32, @bitCast(obj.value))});
        },
        zvm.device.device.Device, *zvm.device.device.Device => {
            std.debug.print(" \x1b[38;2;0;255;255m* Name: {s}\x1b[0m\n", .{obj.name});
        },
        zvm.mem.bus.Region, *zvm.mem.bus.Region => {
            std.debug.print(" \x1b[38;2;0;255;255m* Name: {s}\x1b[0m\n", .{obj.device.name});
            std.debug.print(" \x1b[38;2;0;255;255m* Base: {d} (0x{X:07})\x1b[0m\n", .{obj.base, obj.base});
            std.debug.print(" \x1b[38;2;0;255;255m* Size: {d} (0x{X:07} - 0x{X:07})\x1b[0m\n", .{obj.size, obj.base, obj.base + obj.size});
        },
        u8, u16, u32, u64, comptime_int => std.debug.print(" * {d}\n", .{obj}),
        else => {},
    }
}
