const zvm = @import("../root.zig");
const std = @import("std");

/// The main Bus. Owns memory and memory-mapped device regions
pub const Bus = struct {
    ram: *[0x1000000]u8,
    mapped_regions: [20]?Region,
    region_counter: usize,
    allocator: std.mem.Allocator,

    /// Initializes the Bus
    pub fn init(allocator: std.mem.Allocator) !Bus {
        const ram = try allocator.create([0x1000000]u8);
        @memset(ram, 0);
        return .{
            .ram = ram,
            .mapped_regions = [_]?Region{null} ** 20,
            .region_counter = 0,
            .allocator = allocator,
        };
    }

    pub fn load_rvm(self: *Bus) !void {
        const file = std.fs.cwd().openFile("ROM.rvm", .{ .mode = .read_only }) catch |err| return err;
        defer file.close();
        const stat = file.stat() catch |err| return err;
        std.debug.print("Opened ROM file of size: {d}B\n", .{stat.size});

        var reader = file.reader(self.ram[0..stat.size]);
        reader.interface.readSliceAll(self.ram[0..stat.size]) catch |err| return err;

        if (self.ram[0] != 'R' or self.ram[1] != 'V' or self.ram[2] != 'M') {
            return error.InvalidFileHeader;
        }
    }

    /// Frees the owned RAM
    pub fn deinit(self: *Bus) void {
        self.allocator.destroy(self.ram);
    }

    /// Maps a device to the memory address space
    pub fn map_device(self: *Bus, base: u32, size: u32, device: zvm.device.device.Device) void {
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

    /// Loads a byte from the given address. Forwards call to device if
    /// address falls into memory-mapped device region, uses RAM otherwise.
    pub fn load_u8(self: *Bus, address: usize) u8 {
        zvm.logging.debug("Looking for device to load from...", .{});
        for (0..self.mapped_regions.len) |idx| {
            if (self.mapped_regions[idx]) |region| {
                if (address >= region.base and address < region.base + region.size) {
                    var dev = region.device;
                    zvm.logging.debug("Found device:", dev);
                    return dev.load_u8(address - region.base);
                }
            }
        }
        zvm.logging.debug("Falling back to RAM", .{});
        return self.ram[address];
    }

    /// Stores a byte from the given address. Forwards call to device if
    /// address falls into memory-mapped device region, uses RAM otherwise.
    pub fn store_u8(self: *Bus, address: usize, value: u8) void {
        zvm.logging.debug("Looking for device to store to...", .{});
        for (0..self.mapped_regions.len) |idx| {
            if (self.mapped_regions[idx]) |region| {
                if (address >= region.base and address < region.base + region.size) {
                    var dev = region.device;
                    zvm.logging.debug("Found device:", dev);
                    dev.store_u8(address - region.base, value);
                    return;
                }
            }
        }
        zvm.logging.debug("Falling back to RAM", .{});
        self.ram[address] = value;
    }
};

pub const Region = struct {
    device: zvm.device.device.Device,
    base: u32,
    size: u32,
};
