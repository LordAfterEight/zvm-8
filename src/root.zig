pub const mem = struct {
    pub const bus = @import("memory/memory.zig");
};

pub const device = struct {
    pub const device = @import("device/device.zig");
};

pub const core = struct {
    pub const cpu = @import("cpu/cpu.zig");
    pub const reg = @import("cpu/register.zig");
    pub const alu = @import("cpu/alu.zig");
    pub const cu = @import("cpu/cu.zig");
};

pub const logging =  @import("log/log.zig");
