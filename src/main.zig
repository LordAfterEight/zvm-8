const std = @import("std");
const zvm = @import("zvm");

pub fn main() anyerror!void {
    try zvm.timer.start();
    var bus = try zvm.mem.bus.Bus.init(std.heap.page_allocator);
    defer bus.deinit();
    var cpu = zvm.core.cpu.CPU.init(&bus);

    bus.load_rvm() catch |err| return err;


    bus.ram[0xFFFFFC] = 0x00;
    bus.ram[0xFFFFFD] = 0x00;
    bus.ram[0xFFFFFE] = 0x00;
    bus.ram[0xFFFFFF] = 0x10;

    cpu.reset();

    std.debug.print("IPR: 0x{X:08}\n", .{cpu.ipr.get_value()});

    cpu.run() catch |err| {
        std.debug.print("Error ocurred: {s}", .{@errorName(err)});
    };
}
