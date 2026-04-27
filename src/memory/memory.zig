const zvm = @import("../root.zig");
const std = @import("std");

/// The main Bus. Owns memory and memory-mapped device regions
pub const Bus = struct {
    ram: *[0x10000]u8,
    mapped_regions: [20]?Region,
    region_counter: usize,
    allocator: std.mem.Allocator,

    /// Initializes the Bus
    pub fn init(allocator: std.mem.Allocator) !Bus {
        const ram = try allocator.create([0x10000]u8);
        @memset(ram, 0);
        return .{
            .ram = ram,
            .mapped_regions = [_]?Region{null} ** 20,
            .region_counter = 0,
            .allocator = allocator,
        };
    }

    pub fn load_rvm(self: *Bus) !u16 {
        const file = std.fs.cwd().openFile("ROM.rvm", .{ .mode = .read_only }) catch |err| return err;
        defer file.close();
        const stat = file.stat() catch |err| return err;
        std.debug.print("Opened ROM file of size: {d}B\n", .{stat.size});

        const file_buf = try self.allocator.alloc(u8, stat.size);
        defer self.allocator.free(file_buf);
        var reader = file.reader(file_buf);
        reader.interface.readSliceAll(file_buf) catch |err| return err;

        // Validate magic
        if (file_buf.len < 9 or file_buf[0] != 'R' or file_buf[1] != 'V' or file_buf[2] != 'M') {
            return error.InvalidFileHeader;
        }

        const addr_width = file_buf[4];
        if (addr_width != 2) return error.UnsupportedAddrWidth;

        // Reset vector (little-endian u16)
        const reset_vector: u16 = @as(u16, file_buf[6]) << 8 | file_buf[5];

        // Block count (little-endian u16)
        const block_count: u16 = @as(u16, file_buf[8]) << 8 | file_buf[7];

        var offset: usize = 9; // past header
        for (0..block_count) |_| {
            if (offset >= file_buf.len) return error.UnexpectedEndOfFile;

            const name_len = file_buf[offset];
            offset += 1;

            // Skip block name
            if (offset + name_len > file_buf.len) return error.UnexpectedEndOfFile;
            const name = file_buf[offset..offset + name_len];
            offset += name_len;

            // Load address (little-endian u16)
            if (offset + 2 > file_buf.len) return error.UnexpectedEndOfFile;
            const load_address: u16 = @as(u16, file_buf[offset + 1]) << 8 | file_buf[offset];
            offset += 2;

            // Data length (little-endian u16)
            if (offset + 2 > file_buf.len) return error.UnexpectedEndOfFile;
            const data_length: u16 = @as(u16, file_buf[offset + 1]) << 8 | file_buf[offset];
            offset += 2;

            // Copy block data into RAM
            if (offset + data_length > file_buf.len) return error.UnexpectedEndOfFile;
            const src = file_buf[offset..offset + data_length];
            const dest = self.ram[load_address..load_address + data_length];
            @memcpy(dest, src);

            std.debug.print("Loaded block \"{s}\" ({d} bytes) at 0x{X:0>4}\n", .{ name, data_length, load_address });
            offset += data_length;
        }

        return reset_vector;
    }

    /// Frees the owned RAM
    pub fn deinit(self: *Bus) void {
        self.allocator.destroy(self.ram);
    }

    /// Maps a device to the memory address space
    pub fn map_device(self: *Bus, base: u16, size: u16, device: zvm.device.device.Device) void {
        if (self.mapped_regions[self.region_counter] == null) {
            self.mapped_regions[self.region_counter] = Region {
               .device = device,
               .base = base,
               .size = size
            };
            const r = self.mapped_regions[self.region_counter].?;
            var buf: [64]u8 = undefined;
            const msg = std.fmt.bufPrint(&buf, "Mapped device \"{s}\" @ 0x{X:0>4}..0x{X:0>4} ({d} bytes)", .{ r.device.name, r.base, r.base + r.size - 1, r.size }) catch "Mapped device";
            zvm.logging.info(msg);
            self.region_counter += 1;
        }
    }

    /// Loads a byte from the given address. Forwards call to device if
    /// address falls into memory-mapped device region, uses RAM otherwise.
    pub fn load_u8(self: *Bus, address: usize) u8 {
        for (0..self.mapped_regions.len) |idx| {
            if (self.mapped_regions[idx]) |region| {
                if (address >= region.base and address < region.base + region.size) {
                    var dev = region.device;
                    return dev.load_u8(address - region.base);
                }
            }
        }
        return self.ram[address];
    }

    /// Stores a byte from the given address. Forwards call to device if
    /// address falls into memory-mapped device region, uses RAM otherwise.
    pub fn store_u8(self: *Bus, address: usize, value: u8) void {
        for (0..self.mapped_regions.len) |idx| {
            if (self.mapped_regions[idx]) |region| {
                if (address >= region.base and address < region.base + region.size) {
                    var dev = region.device;
                    dev.store_u8(address - region.base, value);
                    return;
                }
            }
        }
        self.ram[address] = value;
    }
};

pub const Region = struct {
    device: zvm.device.device.Device,
    base: u16,
    size: u16,
};
