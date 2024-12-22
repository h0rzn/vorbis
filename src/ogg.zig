const std = @import("std");
const fs = std.fs;
const vorbis = @import("vorbis.zig");
const flac = @import("flac.zig");
const Reader = @import("reader.zig").Reader;
const builtin = @import("builtin");
const audio_file = @import("audio_file.zig");

pub const SIGNATURE = [4]u8{ 0x4F, 0x67, 0x67, 0x53 }; // ASCII: OggS

pub const OggError = error{
    PageHeaderMissingCapturePattern,
    PacketMalformed,
    PacketBadLength,
};

pub fn readOGG(alloc: std.mem.Allocator, reader: *Reader) !?vorbis.VorbisComment {
    var i: usize = 0;
    var read_capture = false;
    while (true) {
        const page = try readPage(alloc, reader, read_capture);
        defer {
            page.deinit(alloc);
            alloc.destroy(page);
        }

        const vorbis_data = page.vorbisData();
        if (vorbis_data) |data| {
            const comment = try handleVorbis(alloc, data);

            return comment;
        }

        if (page.last()) break;

        i += 1;
        if (i == 1) read_capture = true;
    }
    return null;
}

fn handleVorbis(alloc: std.mem.Allocator, data: []u8) !vorbis.VorbisComment {
    if (data.len <= 7) return OggError.PacketBadLength;

    const vorbis_body = data[7..];
    return try vorbis.parseVorbisComment(alloc, vorbis_body);
}

const Page = struct {
    header: *PageHeader,
    packets: [][]u8,

    pub fn deinit(page: *Page, alloc: std.mem.Allocator) void {
        page.header.deinit(alloc);
        alloc.destroy(page.header);

        for (page.packets) |packet| {
            alloc.free(packet);
        }
        alloc.free(page.packets);
    }

    pub fn last(page: *Page) bool {
        return page.header.header_type_flag == 0x04;
    }

    pub fn vorbisData(page: *Page) ?[]u8 {
        for (page.packets) |packet| {
            if (vorbisComment(packet)) {
                return packet;
            }
        }
        return null;
    }
};

fn readPage(alloc: std.mem.Allocator, reader: *Reader, read_capture: bool) !*Page {
    const page = try alloc.create(Page);
    // read page header
    const page_header = try readPageHeader(alloc, reader, read_capture);
    errdefer {
        page_header.deinit(alloc);
        alloc.destroy(page_header);
    }

    // build packets based on segments
    const packets = try buildPackets(alloc, reader, page_header.segment_table);

    page.header = page_header;
    page.packets = packets;

    return page;
}

// OGG Page Header
const PageHeader = struct {
    capture_pattern: ?[4]u8 = null,
    version: u8,
    header_type_flag: u8,
    granule_position: u64,
    bitstream_serial_number: u32,
    page_sequence_number: u32,
    checksum: u32,
    page_segments: u8,
    segment_table: []u8,

    pub fn deinit(p_header: *PageHeader, alloc: std.mem.Allocator) void {
        if (p_header.segment_table.len > 0) {
            alloc.free(p_header.segment_table);
        }
    }

    pub fn print(p_header: PageHeader) void {
        const tmpl =
            \\PageHeader
            \\  cap pattern = {any}
            \\  version = {d}
            \\  type = {d}
            \\  granule pos = {x}
            \\  bitsream serial = {d}
            \\  page sequence = {d}
            \\  checksum = {d}
            \\  segments = {d}
            \\
        ;

        const cap_pattern = if (p_header.capture_pattern != null) true else false;

        std.debug.print(tmpl, .{ cap_pattern, p_header.version, p_header.header_type_flag, p_header.granule_position, p_header.bitstream_serial_number, p_header.page_sequence_number, p_header.checksum, p_header.page_segments });
    }
};

fn readPageHeader(alloc: std.mem.Allocator, reader: *Reader, read_capture: bool) !*PageHeader {
    var page_header = try alloc.create(PageHeader);
    errdefer alloc.destroy(page_header);

    if (read_capture) {
        const capture_pattern = try reader.readN(4);
        if (!std.mem.eql(u8, &capture_pattern, &SIGNATURE)) {
            return OggError.PageHeaderMissingCapturePattern;
        }
        page_header.capture_pattern = capture_pattern;
    }

    const version = try reader.readOne();
    page_header.version = version;

    const header_type_flag = try reader.readOne();
    page_header.header_type_flag = header_type_flag;

    const granule_position = try reader.readAsT(u64);
    page_header.granule_position = granule_position;

    const bitstream_serial_number = try reader.readAsT(u32);
    page_header.bitstream_serial_number = bitstream_serial_number;

    const page_sequence_number = try reader.readAsT(u32);
    page_header.page_sequence_number = page_sequence_number;

    const checksum = try reader.readAsT(u32);
    page_header.checksum = checksum;

    const page_segments = try reader.readOne();
    page_header.page_segments = page_segments;

    // read segments table
    var segment_table = try alloc.alloc(u8, page_header.page_segments);
    errdefer alloc.free(segment_table);
    for (0..page_header.page_segments) |table_index| {
        const table_field = try reader.readOne();
        segment_table[table_index] = table_field;
    }
    page_header.segment_table = segment_table;

    return page_header;
}

fn buildPackets(alloc: std.mem.Allocator, reader: *Reader, page_segments: []u8) ![][]u8 {
    var packets = std.ArrayList([]u8).init(alloc);
    var current_packet = std.ArrayList(u8).init(alloc);

    errdefer {
        for (packets.items) |packet| {
            alloc.free(packet);
        }

        current_packet.deinit();
        packets.deinit();
    }

    for (page_segments) |segm_len| {
        const segment_data = try reader.readNSlice(alloc, segm_len);
        defer alloc.free(segment_data);
        try current_packet.appendSlice(segment_data);

        // FIXME: handle last segment
        // if (segm_len == 0) {
        //     std.debug.print("LAST SEG\n", .{});
        // }

        // end of packet
        if (segm_len < 255) {
            try packets.append(try current_packet.toOwnedSlice());
        }
    }

    if (current_packet.items.len > 0) {
        std.debug.print("incomplete package found!\n", .{});
        try packets.append(try current_packet.toOwnedSlice());
    }

    current_packet.deinit();
    return packets.toOwnedSlice();
}

pub fn vorbisComment(packet: []u8) bool {
    if (packet.len < 6) return false;

    const ident_byte = packet[0];
    if (ident_byte != 0x03) return false;

    return vorbis.signature(packet[1..7]);
}
