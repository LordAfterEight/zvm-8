const zvm = @import("../root.zig");
const std = @import("std");

pub const Reg32 = Register(4);
pub const Reg8 = Register(1);

pub fn Register(comptime capacity: u8) type {
    return struct {
        name: []const u8,
        id: u8 = 0,
        value: [capacity]u8 = [_]u8{0} ** capacity,

        /// Creates a new 32-bit Register
        pub fn new(name: []const u8) @This() {
            return .{
                .name = name,
            };
        }

        /// Loads an unsigned integer as little endian into the register.
        /// Ignores the value to load if the original value is too large
        /// for the register to hold or if its type is invalid.
        pub fn load_uint(self: *@This(), val: anytype) void {
            switch (@TypeOf(val)) {
                comptime_int, u8, u16, u32 => {
                    const bits: usize = capacity * 8;
                    const max: comptime_int = if (bits == 0) 0 else ((@as(comptime_int, 1) << @intCast(bits)) - 1);
                    if (std.math.maxInt(@TypeOf(val)) > max) {
                        zvm.logging.debug("Maximum possible value based on type exceeds size, ignoring", self);
                        return;
                    }

                    const uval = @as(u32, val);
                    for (0..self.value.len) |idx| {
                        self.value[idx] = @truncate(uval >> @intCast(8 * idx));
                    }

                    zvm.logging.debug("Loaded value:", val);
                    zvm.logging.debug("Reg:", self);
                },
                else => {
                    zvm.logging.debug("Invalid value type, doing nothing", self);
                    return;
                }
            }
        }

        /// Loads a variable length slice as little endian into the register.
        /// Returns an error if the slice length exceeds the register's capacity
        pub fn load_slice(self: *@This(), val: []u8) anyerror!void {
            if (val.len > self.value.len) return error.ExceededCapacity;
            @memcpy(self.value, val);
        }

        /// Returns the inside value as usize, though it will never be larger than
        /// the register bit width allows.
        pub fn get_value(self: *@This()) usize {
            var val: usize = 0;
            var idx = self.value.len;
            while (idx > 0) {
                idx -= 1;
                val = val << 8 | self.value[idx];
            }
            return val;
        }
    };
}
