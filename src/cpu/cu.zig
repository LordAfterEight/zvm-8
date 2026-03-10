const zvm = @import("../root.zig");

/// A CPU Control Unit. Manages the CPU state
/// Owns a back-pointer to the CPU it belongs to.
pub const CU = struct {
    cpu: *zvm.core.cpu.CPU,

    pub fn init(cpu: *zvm.core.cpu.CPU) CU {
        return .{
            .cpu = cpu,
        };
    }
};
