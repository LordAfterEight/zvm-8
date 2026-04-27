const std = @import("std");
const Device = @import("device.zig").Device;

/// Serial port with a status port (offset 0) and data port (offset 1).
///
/// Status port commands (write):
///   0x01 — enter write mode
///   0x02 — flush buffer to stderr
///
/// Status port read:
///   returns current mode (0x00 = idle, 0x01 = write)
///
/// Data port (offset 1):
///   write — appends byte to internal buffer (only in write mode)
///   read  — returns 0 (consumed)
///
/// Map with size 2: bus.map_device(base, 2, serial.device())
pub const Serial = struct {
    const PORT_STATUS = 0;
    const PORT_DATA = 1;

    const CMD_WRITE: u8 = 0x01;
    const CMD_FLUSH: u8 = 0x02;

    mode: enum(u8) { idle = 0x00, write = 0x01 } = .idle,
    buf: std.BoundedArray(u8, 256) = .{},

    pub fn store_u8(self: *Serial, offset: usize, value: u8) void {
        switch (offset) {
            PORT_STATUS => switch (value) {
                CMD_WRITE => self.mode = .write,
                CMD_FLUSH => {
                    std.io.getStdErr().writer().writeAll(self.buf.constSlice()) catch {};
                    self.buf.clear();
                    self.mode = .idle;
                },
                else => {},
            },
            PORT_DATA => {
                if (self.mode == .write) {
                    self.buf.append(value) catch {};
                }
            },
            else => {},
        }
    }

    pub fn load_u8(self: *Serial, offset: usize) u8 {
        return switch (offset) {
            PORT_STATUS => @intFromEnum(self.mode),
            else => 0,
        };
    }

    pub fn device(self: *Serial) Device {
        return Device.create(self, "Serial Port");
    }
};
