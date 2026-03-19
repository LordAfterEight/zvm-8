const zvm = @import("../root.zig");

pub const Device = struct {
    name: []const u8,
    inner: *anyopaque,
    vtable: *const VTable,

    pub fn create(device: anytype, name: []const u8) Device {
        const T = @TypeOf(device.*);
        const vtable = struct {
            fn load_u8(ptr: *anyopaque, offset: usize) u8 {
                return @as(*T, @ptrCast(@alignCast(ptr))).load_u8(offset);
            }
            fn store_u8(ptr: *anyopaque, offset: usize, value: u8) void {
                @as(*T, @ptrCast(@alignCast(ptr))).store_u8(offset, value);
            }
        };
        return .{
            .name = name,
            .inner = device,
            .vtable = &.{
                .load_u8 = vtable.load_u8,
                .store_u8 = vtable.store_u8,
            },
        };
    }

    pub fn load_u8(self: *Device, offset: usize) u8 {
        return self.vtable.load_u8(self.inner, offset);
    }

    pub fn store_u8(self: *Device, offset: usize, value: u8) void {
        self.vtable.store_u8(self.inner, offset, value);
    }
};

pub const VTable = struct {
    load_u8: *const fn(self: *anyopaque, offset: usize) u8,
    store_u8: *const fn(self: *anyopaque, offset: usize, value: u8) void,
};
