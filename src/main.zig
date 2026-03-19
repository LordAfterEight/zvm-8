const std = @import("std");
const zvm = @import("zvm");

pub fn main() anyerror!void {
    try zvm.timer.start();
    var cpu = zvm.core.cpu.CPU.init();
    var bus = zvm.mem.bus.Bus.init();
    cpu.connect_bus(&bus);

    bus.ram[0xFFFFFC] = 0x1A;
    bus.ram[0xFFFFFD] = 0x1B;
    bus.ram[0xFFFFFE] = 0x1C;
    bus.ram[0xFFFFFF] = 0x1D;

    cpu.reset();

    std.debug.print("IPR: {X}", .{cpu.ipr.get_value()});
}
