const std = @import("std");
const zvm = @import("zvm");

pub fn main() anyerror!void {
    var mode: zvm.core.cpu.Mode = .debug;
    var args = std.process.args();
    _ = args.skip(); // skip program name
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--release")) {
            mode = .release;
        } else if (std.mem.eql(u8, arg, "--debug")) {
            mode = .debug;
        }
    }

    try zvm.timer.start();
    var bus = try zvm.mem.bus.Bus.init(std.heap.page_allocator);
    defer bus.deinit();

    const reset_vector = bus.load_rvm() catch |err| return err;

    var cpu = zvm.core.cpu.CPU.init(&bus, mode, reset_vector);
    cpu.reset();

    std.debug.print("IPR: 0x{X:0>4}\n", .{cpu.ipr.get_value()});

    cpu.run() catch |err| {
        if (err != error.Halted) {
            std.process.exit(1);
        }
    };
}
