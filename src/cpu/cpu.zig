const std = @import("std");
const zvm = @import("../root.zig");
const OpCode = @import("opcodes.zig").OpCode;

pub const STACK_TOP: u16 = 0xFFFD;
pub const STACK_BOTTOM: u16 = 0xFF00;

pub const Mode = enum { debug, release };

pub const CPU = struct {
    /// General Purpose Register, 8-bit
    gpr: [32]zvm.core.reg.Reg8,
    /// Instruction Register, 8-bit
    ir: zvm.core.reg.Reg8,
    /// Instruction Pointer Register, 16-bit
    ipr: zvm.core.reg.Reg16,
    /// Stack Pointer Register, 16-bit
    spr: zvm.core.reg.Reg16,
    /// Arithmetic Logic Unit
    alu: zvm.core.alu.ALU,

    /// VM execution mode
    mode: Mode,

    /// Reset vector address
    reset_vector: u16,

    /// The System Bus
    bus: *zvm.mem.bus.Bus,

    /// Initializes the CPU with a connected system bus
    pub fn init(bus: *zvm.mem.bus.Bus, mode: Mode, reset_vector: u16) CPU {
        var cpu = CPU{
            .gpr = [_]zvm.core.reg.Reg8{.new("GPR")} ** 32,
            .ir = zvm.core.reg.Reg8.new("Instruction Register"),
            .ipr = zvm.core.reg.Reg16.new("Instruction Pointer"),
            .spr = zvm.core.reg.Reg16.new("Stack Pointer"),
            .alu = zvm.core.alu.ALU.init(),
            .mode = mode,
            .reset_vector = reset_vector,
            .bus = bus,
        };
        for (0..cpu.gpr.len) |i| {
            cpu.gpr[i].id = @intCast(i);
        }
        return cpu;
    }

    /// Advances the IPR, wrapping
    pub fn step(self: *CPU) void {
        self.ipr.load_uint(@as(u16, @intCast(self.ipr.get_value() + 1)));
    }

    /// Loads a byte from the given address
    pub fn load(self: *CPU, address: usize) u8 {
        return self.bus.load_u8(address);
    }

    /// Stores a byte to the given address
    pub fn store(self: *CPU, address: usize, value: u8) void {
        self.bus.store_u8(address, value);
    }

    /// Resets the CPU: initializes the stack pointer and jumps to the reset vector.
    pub fn reset(self: *CPU) void {
        self.spr.load_uint(STACK_TOP);
        self.ipr.load_uint(self.reset_vector);
    }

    /// Reads the next byte operand (steps IPR, then reads)
    fn fetch(self: *CPU) u8 {
        self.step();
        return self.bus.load_u8(self.ipr.get_value());
    }

    /// Reads a 16-bit little-endian address from the next two bytes
    fn fetch_addr(self: *CPU) u16 {
        const lo = self.fetch();
        const hi = self.fetch();
        return @as(u16, hi) << 8 | lo;
    }

    /// Pushes a single byte onto the stack (grows downward)
    fn stack_push(self: *CPU, value: u8) !void {
        if (self.spr.get_value() <= STACK_BOTTOM) {
            if (self.mode == .debug) {
                std.debug.print("Stack overflow at SPR=0x{X:0>4}\n", .{self.spr.get_value()});
            }
            return error.StackOverflow;
        }
        self.spr.load_uint(@as(u16, @intCast(self.spr.get_value() - 1)));
        self.bus.store_u8(self.spr.get_value(), value);
    }

    /// Pops a single byte from the stack (grows downward)
    fn stack_pop(self: *CPU) !u8 {
        if (self.spr.get_value() >= STACK_TOP) {
            if (self.mode == .debug) {
                std.debug.print("Stack underflow at SPR=0x{X:0>4}\n", .{self.spr.get_value()});
            }
            return error.StackUnderflow;
        }
        const value = self.bus.load_u8(self.spr.get_value());
        self.spr.load_uint(@as(u16, @intCast(self.spr.get_value() + 1)));
        return value;
    }

    /// Pushes a 16-bit value onto the stack (little-endian, grows downward)
    fn push16(self: *CPU, value: u16) !void {
        try self.stack_push(@truncate(value >> 8));
        try self.stack_push(@truncate(value));
    }

    /// Pops a 16-bit value from the stack (little-endian, grows downward)
    fn pop16(self: *CPU) !u16 {
        const lo = try self.stack_pop();
        const hi = try self.stack_pop();
        return @as(u16, hi) << 8 | lo;
    }

    var fmt_buf: [64]u8 = undefined;

    fn fmt(comptime f: []const u8, args: anytype) []const u8 {
        return std.fmt.bufPrint(&fmt_buf, f, args) catch "...";
    }

    fn log(self: *CPU, op: []const u8, detail: []const u8) void {
        if (self.mode == .debug) {
            zvm.logging.trace(@intCast(self.ipr.get_value()), op, detail);
        }
    }

    /// Executes one full cycle
    pub fn tick(self: *CPU) anyerror!void {
        const pc = self.ipr.get_value();
        self.ir.load_uint(self.bus.load_u8(pc));

        const val: OpCode = @enumFromInt(self.ir.get_value());

        switch (val) {
            .LDI => {
                const reg_idx = self.fetch();
                const value = self.fetch();
                self.gpr[reg_idx].load_uint(value);
                self.log("LDI", fmt("r{d} <- 0x{X:0>2}", .{ reg_idx, value }));
                self.step();
            },
            .STI => {
                const reg_idx = self.fetch();
                const addr = self.fetch_addr();
                self.log("STI", fmt("[0x{X:0>4}] <- r{d} (0x{X:0>2})", .{ addr, reg_idx, @as(u8, @intCast(self.gpr[reg_idx].get_value())) }));
                self.bus.store_u8(addr, @intCast(self.gpr[reg_idx].get_value()));
                self.step();
            },
            .JMP => {
                const addr = self.fetch_addr();
                self.log("JMP", fmt("-> 0x{X:0>4}", .{addr}));
                self.ipr.load_uint(addr);
            },
            .JMR => {
                const reg_idx = self.fetch();
                const addr = @as(u16, @intCast(self.gpr[reg_idx].get_value()));
                self.log("JMR", fmt("-> r{d} (0x{X:0>4})", .{ reg_idx, addr }));
                self.ipr.load_uint(addr);
            },
            .BRA => {
                const addr = self.fetch_addr();
                const ret_addr = @as(u16, @intCast(self.ipr.get_value() +% 1));
                self.log("BRA", fmt("-> 0x{X:0>4}  ret=0x{X:0>4}", .{ addr, ret_addr }));
                try self.push16(ret_addr);
                self.ipr.load_uint(addr);
            },
            .BRR => {
                const reg_idx = self.fetch();
                const ret_addr = @as(u16, @intCast(self.ipr.get_value() +% 1));
                const target = @as(u16, @intCast(self.gpr[reg_idx].get_value()));
                self.log("BRR", fmt("-> r{d} (0x{X:0>4})  ret=0x{X:0>4}", .{ reg_idx, target, ret_addr }));
                try self.push16(ret_addr);
                self.ipr.load_uint(target);
            },
            .RTR => {
                const addr = try self.pop16();
                self.log("RTR", fmt("-> 0x{X:0>4}", .{addr}));
                self.ipr.load_uint(addr);
            },
            .ADD => {
                const r1 = self.fetch();
                const r2 = self.fetch();
                const rd = self.fetch();
                const a: u8 = @intCast(self.gpr[r1].get_value());
                const b: u8 = @intCast(self.gpr[r2].get_value());
                const result = a +% b;
                self.log("ADD", fmt("r{d} <- r{d} + r{d} (0x{X:0>2} + 0x{X:0>2} = 0x{X:0>2})", .{ rd, r1, r2, a, b, result }));
                self.gpr[rd].load_uint(result);
                self.step();
            },
            .SUB => {
                const r1 = self.fetch();
                const r2 = self.fetch();
                const rd = self.fetch();
                const a: u8 = @intCast(self.gpr[r1].get_value());
                const b: u8 = @intCast(self.gpr[r2].get_value());
                const result = a -% b;
                self.log("SUB", fmt("r{d} <- r{d} - r{d} (0x{X:0>2} - 0x{X:0>2} = 0x{X:0>2})", .{ rd, r1, r2, a, b, result }));
                self.gpr[rd].load_uint(result);
                self.step();
            },
            .POW => {
                const r1 = self.fetch();
                const r2 = self.fetch();
                const rd = self.fetch();
                const base: u8 = @intCast(self.gpr[r1].get_value());
                const exp: u8 = @intCast(self.gpr[r2].get_value());
                var result: u8 = 1;
                for (0..exp) |_| {
                    result *%= base;
                }
                self.log("POW", fmt("r{d} <- r{d} ** r{d} (0x{X:0>2} ** 0x{X:0>2} = 0x{X:0>2})", .{ rd, r1, r2, base, exp, result }));
                self.gpr[rd].load_uint(result);
                self.step();
            },
            .AND => {
                const r1 = self.fetch();
                const r2 = self.fetch();
                const rd = self.fetch();
                const a: u8 = @intCast(self.gpr[r1].get_value());
                const b: u8 = @intCast(self.gpr[r2].get_value());
                const result = a & b;
                self.log("AND", fmt("r{d} <- r{d} & r{d} (0x{X:0>2} & 0x{X:0>2} = 0x{X:0>2})", .{ rd, r1, r2, a, b, result }));
                self.gpr[rd].load_uint(result);
                self.step();
            },
            .ORI => {
                const reg_idx = self.fetch();
                const imm = self.fetch();
                const a: u8 = @intCast(self.gpr[reg_idx].get_value());
                const result = a | imm;
                self.log("ORI", fmt("r{d} <- r{d} | 0x{X:0>2} (0x{X:0>2} | 0x{X:0>2} = 0x{X:0>2})", .{ reg_idx, reg_idx, imm, a, imm, result }));
                self.gpr[reg_idx].load_uint(result);
                self.step();
            },
            .ORR => {
                const r1 = self.fetch();
                const r2 = self.fetch();
                const rd = self.fetch();
                const a: u8 = @intCast(self.gpr[r1].get_value());
                const b: u8 = @intCast(self.gpr[r2].get_value());
                const result = a | b;
                self.log("ORR", fmt("r{d} <- r{d} | r{d} (0x{X:0>2} | 0x{X:0>2} = 0x{X:0>2})", .{ rd, r1, r2, a, b, result }));
                self.gpr[rd].load_uint(result);
                self.step();
            },
            .XOR => {
                const r1 = self.fetch();
                const r2 = self.fetch();
                const rd = self.fetch();
                const a: u8 = @intCast(self.gpr[r1].get_value());
                const b: u8 = @intCast(self.gpr[r2].get_value());
                const result = a ^ b;
                self.log("XOR", fmt("r{d} <- r{d} ^ r{d} (0x{X:0>2} ^ 0x{X:0>2} = 0x{X:0>2})", .{ rd, r1, r2, a, b, result }));
                self.gpr[rd].load_uint(result);
                self.step();
            },
            .PSH => {
                const reg_idx = self.fetch();
                const value: u8 = @intCast(self.gpr[reg_idx].get_value());
                self.log("PSH", fmt("r{d} (0x{X:0>2})  SPR=0x{X:0>4}", .{ reg_idx, value, self.spr.get_value() }));
                try self.stack_push(value);
                self.step();
            },
            .POP => {
                const reg_idx = self.fetch();
                const value = try self.stack_pop();
                self.log("POP", fmt("r{d} <- 0x{X:0>2}  SPR=0x{X:0>4}", .{ reg_idx, value, self.spr.get_value() }));
                self.gpr[reg_idx].load_uint(value);
                self.step();
            },
            .SRE => {
                self.log("SRE", fmt("-> 0x{X:0>4}", .{self.reset_vector}));
                self.reset();
            },
            .HRE => {
                self.log("HRE", fmt("-> 0x{X:0>4}", .{self.reset_vector}));
                self.reset();
                for (&self.gpr) |*reg| {
                    reg.load_uint(@as(u8, 0));
                }
            },
            .HLT => {
                self.log("HLT", "");
                return error.Halted;
            },
            .NOP => {
                self.log("NOP", "");
                self.step();
            },
        }
    }

    /// Starts the CPU
    pub fn run(self: *CPU) anyerror!void {
        while (true) {
            self.tick() catch |err| {
                switch (self.mode) {
                    .debug => {
                        std.debug.print("CPU error: {s}\n", .{@errorName(err)});
                        std.debug.print("  IPR=0x{X:0>4} SPR=0x{X:0>4}\n", .{ self.ipr.get_value(), self.spr.get_value() });
                        std.debug.print("Continue? [y/N]: ", .{});
                        var buf: [2]u8 = undefined;
                        const stdin = std.fs.File.stdin();
                        const n = stdin.read(&buf) catch return err;
                        if (n == 0 or (buf[0] != 'y' and buf[0] != 'Y')) {
                            return err;
                        }
                    },
                    .release => return err,
                }
            };
        }
    }
};
