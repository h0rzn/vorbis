const std = @import("std");
const fs = std.fs;
const vorbis = @import("vorbis.zig");
const flac = @import("flac.zig");
const Reader = @import("reader.zig").Reader;
const builtin = @import("builtin");
const audio_file = @import("audio_file.zig");

/// SIGNATURE are the "magic bytes" that mark ogg.
/// ASCII: OggS
pub const SIGNATURE = [4]u8{ 0x4F, 0x67, 0x67, 0x53 };

pub const OggError = error{
    /// PageHeaderMissingCapturePattern is returned if
    /// a page header is missing the ogg signature
    PageHeaderMissingCapturePattern,
    /// PacketMalformed is a generic error when unexpected bytes are read.
    PacketMalformed,
    /// PacketBadLength is returned when a packet ends unexpectedly
    PacketBadLength,
    /// VorbisMissing is returned if the vorbis signature is missing
    VorbisMissing,
};

/// MAX_PAGE_READ is the maximum of pages to read
const MAX_PAGE_READ = 10;

/// readOgg uses the reader to parse VorbisComment from a audio file.
/// Pages are continuously parsed until vorbis data is found and returned.
pub fn readOGG(alloc: std.mem.Allocator, reader: *Reader) !vorbis.VorbisComment {
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
        if (i == MAX_PAGE_READ) break;
    }
    return OggError.VorbisMissing;
}

/// handleVorbis is a convenience function that strips
/// the vorbis signature and calls the parse function for the body.
fn handleVorbis(alloc: std.mem.Allocator, data: []u8) !vorbis.VorbisComment {
    if (data.len <= 7) return OggError.PacketBadLength;

    const vorbis_body = data[7..];
    return try vorbis.parseVorbisComment(alloc, vorbis_body);
}

/// Page represents a logical unit in an OGG file, consisting of a header and associated packets.
///
/// - **Header**: Metadata about the page, such as flags and checksums, encapsulated in a `PageHeader`.
/// - **Packets**: A collection of data segments (`[][]u8`) that are part of the logical bitstream.
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

    /// `last` indicates if this page is the last page,
    /// based on the header `header_type_flag`
    pub fn last(page: *Page) bool {
        return page.header.header_type_flag == 0x04;
    }

    /// `vorbisData` returns the parsed vorbis packet data
    /// from a packet if exists
    pub fn vorbisData(page: *Page) ?[]u8 {
        for (page.packets) |packet| {
            if (vorbisComment(packet)) {
                return packet;
            }
        }
        return null;
    }
};

/// `readPage` reads a `*Page` from `*Reader`. The packets are built from
/// the segments of the `Page` body.
fn readPage(alloc: std.mem.Allocator, reader: *Reader, read_capture: bool) !*Page {
    const page = try alloc.create(Page);
    errdefer alloc.destroy(page);

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

/// `PageHeader` represents a OGG Page Header. This struct
/// maps all fields of a header.
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

/// `readPageHeader` uses the `*Reader` to create a `*PageHeader`.
/// If `read_capture` is `true` the first 4 bytes are expected
/// to be the ogg signature.
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

/// `buildPackets` constructs packets from the given page segments in an OGG file.
///
/// This function processes the page segments of an OGG file to build packets,
/// where each packet is represented as a `[]u8`. Packets are formed by aggregating
/// segment data.
/// - **Rules for aggregation**:
///     - segment len of 255: segment is continuation of previous
///     - segment len of 0-254: last segment of packet
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

        // end of packet
        if (segm_len < 255) {
            try packets.append(try current_packet.toOwnedSlice());
        }
    }

    if (current_packet.items.len > 0) {
        try packets.append(try current_packet.toOwnedSlice());
    }

    current_packet.deinit();
    return packets.toOwnedSlice();
}

/// `vorbisComment` identifies a packet as a "vorbis-packet".
/// Also returns false if packet length < 6. The first byte read
/// is the identification byte (`0x03`: vorbis comment).
//  - 0x01: Identification header.
//  - 0x03: Comment header (Vorbis comments).
//  - 0x05: Setup header.
pub fn vorbisComment(packet: []u8) bool {
    if (packet.len < 7) return false;

    const ident_byte = packet[0];
    if (ident_byte != 0x03) return false;

    return vorbis.signature(packet[1..7]);
}
