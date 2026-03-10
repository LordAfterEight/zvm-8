const zvm = @import("../root.zig");

pub const Device = struct {
    name: []const u8,
    inner: *anyopaque,

    pub fn create(device: *anyopaque, name: []const u8) Device {
        return .{
            .name = name,
            .inner = device,
        };
    }
};
