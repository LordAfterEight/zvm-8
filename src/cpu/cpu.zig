const zvm = @import("../root.zig");

pub const CPU = struct {
    /// General Purpose Register, 8-bit
    gpr: [32]zvm.core.reg.Reg8,
    /// Instruction Pointer Register, 32-bit
    ipr: zvm.core.reg.Reg32,
    /// Stack Pointer Register, 32-bit
    spr: zvm.core.reg.Reg32,
    /// Arithmetic Logic Unit
    alu: zvm.core.alu.ALU,

    /// The System Bus
    bus: *zvm.mem.bus.Bus,

    /// Initializes the CPU
    pub fn init() CPU {
        var cpu = CPU {
            .gpr = [_]zvm.core.reg.Reg8{.new("GPR")} ** 32,
            .ipr = zvm.core.reg.Reg32.new("Instruction Pointer"),
            .spr = zvm.core.reg.Reg32.new("Stack Pointer"),
            .alu = zvm.core.alu.ALU.init(),
            .bus = undefined,
        };
        for (0..cpu.gpr.len) |i| {
            cpu.gpr[i].id = @intCast(i);
        }
        return cpu;
    }

    /// Simply provides the CPU with a pointer to a system bus
    pub fn connect_bus(self: *CPU, bus: *zvm.mem.bus.Bus) void {
        zvm.logging.debug("Connecting bus to CPU", .{});
        self.bus = bus;
    }

    /// Loads a byte from the given address
    pub fn load(self: *CPU, address: usize) u8 {
        return self.bus.load_u8(address);
    }

    /// Stores a byte to the given address
    pub fn store(self: *CPU, address: usize, value: u8) void {
        self.bus.store_u8(address, value);
    }

    /// Executes one full cycle
    pub fn tick() anyerror!void {
        return;
    }
};
