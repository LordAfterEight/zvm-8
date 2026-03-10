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

    /// Control Unit.
    cu: zvm.core.cu.CU,

    /// Initializes the CPU
    pub fn init() CPU {
        var cpu = CPU {
            .gpr = [_]zvm.core.reg.Reg8{.new("GPR")} ** 32,
            .ipr = zvm.core.reg.Reg32.new("Instruction Pointer"),
            .spr = zvm.core.reg.Reg32.new("Stack Pointer"),
            .alu = zvm.core.alu.ALU.init(),
            .bus = undefined,
            .cu = undefined
        };
        for (0..cpu.gpr.len) |i| {
            cpu.gpr[i].id = @intCast(i);
        }
        cpu.cu = zvm.core.cu.CU.init(&cpu);
        return cpu;
    }

    /// Simply provides the CPU with a pointer to a system bus
    pub fn connect_bus(self: *CPU, bus: *zvm.mem.bus.Bus) void {
        zvm.logging.debug("Connecting bus to CPU", .{});
        self.bus = bus;
    }

    /// Executes one full cycle
    pub fn tick() anyerror!void {
        return;
    }
};
