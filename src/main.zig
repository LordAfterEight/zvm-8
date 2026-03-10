const std = @import("std");
const zvm = @import("zvm");

pub fn main() anyerror!void {
    try zvm.timer.start();
    var cpu = zvm.core.cpu.CPU.init();
    var bus = zvm.mem.bus.Bus.init();

    cpu.gpr[10].load_uint(@as(u16, 256));

    cpu.connect_bus(&bus);

    const cpu_device = zvm.device.device.Device.create(&cpu, "CPU Device");

    bus.map_device(0x1000, 32, cpu_device);
}
