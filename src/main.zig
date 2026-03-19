const std = @import("std");
const zvm = @import("zvm");

pub fn main() anyerror!void {
    try zvm.timer.start();
    var cpu = zvm.core.cpu.CPU.init();
    var bus = zvm.mem.bus.Bus.init();
    var flash = zvm.components.flash.Flash.init();


    cpu.connect_bus(&bus);

    const flash_device = zvm.device.device.Device.create(&flash, "Storage");
    bus.map_device(0x10000, 0x8000, flash_device);

    cpu.ipr.load_uint(@as(u32, 0xFFFFFFC));

    const addr = 0x10010;

    cpu.store(addr, 253);
    const val = cpu.load(addr);
    std.debug.print("RAM value at 0x{X:07}: {d}", .{addr, val});
}
