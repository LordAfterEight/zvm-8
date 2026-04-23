const std = @import("std");
const zvm = @import("../root.zig");
const OpCode = @import("opcodes.zig").OpCode;

pub const CPU = struct {
    /// General Purpose Register, 8-bit
    gpr: [32]zvm.core.reg.Reg8,
    /// Instruction Register, 8-bit
    ir: zvm.core.reg.Reg8,
    /// Instruction Pointer Register, 32-bit
    ipr: zvm.core.reg.Reg32,
    /// Stack Pointer Register, 32-bit
    spr: zvm.core.reg.Reg32,
    /// Arithmetic Logic Unit
    alu: zvm.core.alu.ALU,

    /// The System Bus
    bus: *zvm.mem.bus.Bus,

    /// Initializes the CPU with a connected system bus
    pub fn init(bus: *zvm.mem.bus.Bus) CPU {
        var cpu = CPU{
            .gpr = [_]zvm.core.reg.Reg8{.new("GPR")} ** 32,
            .ir = zvm.core.reg.Reg8.new("Instruction Register"),
            .ipr = zvm.core.reg.Reg32.new("Instruction Pointer"),
            .spr = zvm.core.reg.Reg32.new("Stack Pointer"),
            .alu = zvm.core.alu.ALU.init(),
            .bus = bus,
        };
        for (0..cpu.gpr.len) |i| {
            cpu.gpr[i].id = @intCast(i);
        }
        return cpu;
    }

    /// Advances the IPR, wrapping
    pub fn step(self: *CPU) void {
        self.ipr.load_uint(@as(u32, @intCast(self.ipr.get_value() + 1)));
    }

    /// Loads a byte from the given address
    pub fn load(self: *CPU, address: usize) u8 {
        return self.bus.load_u8(address);
    }

    /// Stores a byte to the given address
    pub fn store(self: *CPU, address: usize, value: u8) void {
        self.bus.store_u8(address, value);
    }

    /// Jumps to the reset vector, gets a new address to continue from and jumps there.
    /// Clobbers GPRs 0-3
    pub fn reset(self: *CPU) void {
        self.ipr.load_uint(@as(u32, 0xFFFFFC));
        self.gpr[0].load_uint(self.bus.load_u8(self.ipr.get_value()));
        self.step();
        self.gpr[1].load_uint(self.bus.load_u8(self.ipr.get_value()));
        self.step();
        self.gpr[2].load_uint(self.bus.load_u8(self.ipr.get_value()));
        self.step();
        self.gpr[3].load_uint(self.bus.load_u8(self.ipr.get_value()));
        self.ipr.load_uint(@as(u32, @intCast(
            self.gpr[0].get_value() << 24
            | self.gpr[1].get_value() << 16
            | self.gpr[2].get_value() << 8
            | self.gpr[3].get_value()
        )));
    }

    /// Executes one full cycle
    pub fn tick(self: *CPU) anyerror!void {
        const ipr_val = self.ipr.get_value();
        std.debug.print("IPR: 0x{X:0>2}\n", .{ipr_val});
        const bus_val = self.bus.load_u8(ipr_val);
        std.debug.print("BUS: 0x{X:0>2}\n", .{bus_val});
        self.ir.load_uint(bus_val);
        const ir_val = self.ir.get_value();
        std.debug.print("IR: 0x{X:0>2}\n", .{ir_val});

        const val: OpCode = @enumFromInt(self.ir.get_value());
        std.debug.print("Value: 0x{X:0>2}\n", .{val});

        switch (val) {
            OpCode.JMP => {
                self.step();
                self.ir.load_uint(self.ipr.get_value());
                const addr1 = self.ir.get_value();
                self.step();
                self.ir.load_uint(self.ipr.get_value());
                const addr2 = self.ir.get_value();

                self.ipr.load_uint(@as(u16, @intCast(addr1 << @as(usize, 8) | addr2)));
            },
            else => return error.InvalidOpCode
        }
        return;
    }

    /// Starts the CPU
    pub fn run(self: *CPU) anyerror!void {
        while (true) {
            try self.tick();
        }
    }
};
