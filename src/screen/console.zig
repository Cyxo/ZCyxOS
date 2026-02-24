const std = @import("std");
const limine = @import("limine");

const font = @import("font.zig").default_font;

var g_row: usize = 0;
var g_column: usize = 0;
var g_color: Color = .init(.light_gray, .black);
var g_framebuffer: *limine.Framebuffer = undefined;

pub const ColorType = enum(u32) {
    black = 0x21222B,
    blue = 0xBE92FA,
    green = 0x50FB79,
    cyan = 0x8BE9FE,
    red = 0xFC5655,
    magenta = 0xFF78C8,
    brown = 0xEEFB90,
    light_gray = 0xF6F6F4,
    dark_gray = 0x6572A2,
    light_blue = 0xD6ABFE,
    light_green = 0x69FE96,
    light_cyan = 0xA5FEFD,
    light_red = 0xFB706F,
    light_magenta = 0xFE92E0,
    light_brown = 0xFDFDA7,
    white = 0xFFFFFF,
};

const Color = packed struct(u64) {
    fg: ColorType,
    bg: ColorType,

    pub fn init(fg: ColorType, bg: ColorType) Color {
        return .{ .fg = fg, .bg = bg };
    }
};

/// Initialize VGA
pub fn init(framebuffer: *limine.Framebuffer) void {
    g_framebuffer = framebuffer;
    clear();
}

/// Set Color for VGA
pub fn setColor(fg: Color, bg: Color) void {
    g_color = Color.init(fg, bg);
}

/// Clear the screen
pub fn clear() void {
    const size = g_framebuffer.pitch * g_framebuffer.height / 4;
    const fb_ptr: [*]volatile u32 = @ptrCast(@alignCast(g_framebuffer.address));
    @memset(fb_ptr[0..size], @intFromEnum(g_color.bg));
}

/// Print character with color at specific position
pub fn printCharAt(char: u8, color: Color, x: usize, y: usize) void {
    const base_index = y * (g_framebuffer.pitch / 4) + x;
    const fb_ptr: [*]volatile u32 = @ptrCast(@alignCast(g_framebuffer.address));
    fb_ptr[10 + 10 * g_framebuffer.pitch / 4] = 0xff0000;
    fb_ptr[15 + 10 * g_framebuffer.pitch / 4] = char;
    const glyph = font.glyphs[char];
    fb_ptr[20 + 10 * g_framebuffer.pitch / 4] = glyph[0];
    for (0..16) |py| {
        const line = glyph[py];
        const cy = py * (g_framebuffer.pitch / 4);
        for (0..8) |px| {
            const bit = (line >> @as(u3, @intCast(7 - px))) & 1;
            if (bit == 1) {
                fb_ptr[base_index + cy + px] = @intFromEnum(color.fg);
            } else {
                fb_ptr[base_index + cy + px] = @intFromEnum(color.bg);
            }
        }
    }
}

/// INFO: Scrolling is left as an exercise for the reader
fn checkAndScroll() void {
    const size = g_framebuffer.pitch * g_framebuffer.height * 4;
    const line_bytes = g_framebuffer.pitch * 16;
    const fb_ptr: [*]volatile u32 = @ptrCast(@alignCast(g_framebuffer.address));
    @memmove(fb_ptr[line_bytes..size], fb_ptr[0 .. size - line_bytes]);
    @memset(fb_ptr[size - line_bytes .. size], @intFromEnum(g_color.bg));
}

/// Print character to the VGA
pub fn printChar(char: u8) void {
    switch (char) {
        '\n' => {
            g_column = 0;
            g_row += 16;
            checkAndScroll();
        },
        else => {
            printCharAt(char, g_color, g_column, g_row);
            g_column += 8;
            if (g_column == g_framebuffer.width) {
                g_column = 0;
                g_row += 16;
                checkAndScroll();
            }
        },
    }
}

/// Implementation of std.Io.Writer.vtable.drain function.
/// When flush is called or the writer buffer is full this function is called.
/// This function first writes all data of writer buffer after that it writes
/// the argument data in which the last element is written splat times.
fn drain(w: *std.Io.Writer, data: []const []const u8, splat: usize) !usize {
    // the length of data must not be zero
    std.debug.assert(data.len != 0);

    var consumed: usize = 0;
    const pattern = data[data.len - 1];
    const splat_len = pattern.len * splat;

    // If buffer is not empty write it first
    if (w.end != 0) {
        printString(w.buffered());
        w.end = 0;
    }

    // Now write all data except last element
    for (data[0 .. data.len - 1]) |bytes| {
        printString(bytes);
        consumed += bytes.len;
    }

    // If out patter (i.e. last element of data) is non zero len then write splat times
    switch (pattern.len) {
        0 => {},
        else => {
            for (0..splat) |_| {
                printString(pattern);
            }
        },
    }
    // Now we have to return how many bytes we consumed from data
    consumed += splat_len;
    return consumed;
}

/// Returns std.Io.Writer implementation for this console
pub fn writer(buffer: []u8) std.Io.Writer {
    return .{
        .buffer = buffer,
        .end = 0,
        .vtable = &.{
            .drain = drain,
        },
    };
}

/// Print string to VGA
pub fn printString(str: []const u8) void {
    for (str) |char| {
        printChar(char);
    }
}

/// Print with standard zig format to VGA
pub fn print(comptime fmt: []const u8, args: anytype) void {
    var w = writer(&.{});
    w.print(fmt, args) catch return;
    printString(w.buffer);
}
