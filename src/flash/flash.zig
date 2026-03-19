pub const Flash = struct {
    data: [32768]u8,

    pub fn init() Flash {
        return .{
            .data = [_]u8{0} ** 32768,
        };
    }

    pub fn load_u8(self: *Flash, address: usize) u8 {
        return self.data[address];
    }

    pub fn store_u8(self: *Flash, address: usize, value: u8) void {
        self.data[address] = value;
    }
};
