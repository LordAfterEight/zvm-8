const zvm = @import("../root.zig");

/// The main Bus. Owns memory and memory-mapped device regions
pub const Bus = struct {
    ram: [0x1000000]u8,
    mapped_regions: [20]?Region,
    region_counter: usize,

    /// Initializes the Bus
    pub fn init() Bus {
        return .{
            .ram = [_]u8{0} ** 0x1000000,
            .mapped_regions = [_]?Region{null} ** 20,
            .region_counter = 0,
        };
    }

    /// Maps a device to the memory address space
    pub fn map_device(self: *Bus, base: u16, size: u16, device: zvm.device.device.Device) void {
        zvm.logging.debug("Mapping device", device);
        if (self.mapped_regions[self.region_counter] == null) {
            zvm.logging.debug("Found empty region", null);
            self.mapped_regions[self.region_counter] = Region {
               .device = device,
               .base = base,
               .size = size
            };
            zvm.logging.debug("\x1b[38;2;50;255;50mMapped device\x1b[0m", self.mapped_regions[self.region_counter].?);

            self.region_counter += 1;
        }
    }
};

pub const Region = struct {
    device: zvm.device.device.Device,
    base: u16,
    size: u16,
};
