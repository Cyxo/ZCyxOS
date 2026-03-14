const limine = @import("limine");
const math = @import("std").math;

fn Color() type {
    return struct {
        r: u32,
        g: u32,
        b: u32,
    };
}

fn from_hsv(hue: f64, saturation: f64, value: f64) Color() {
    var color = Color(){ .r = 0, .g = 0, .b = 0 };

    // Red channel
    var k = @mod(5.0 + hue, 6.0);
    var t = 4 - k;
    k = if (t < k) t else k;
    k = if (k < 1) k else 1;
    k = if (k > 0) k else 0;
    color.r = @intFromFloat((value - value * saturation * k) * 255);

    // Green channel
    k = @mod(3.0 + hue, 6.0);
    t = 4 - k;
    k = if (t < k) t else k;
    k = if (k < 1) k else 1;
    k = if (k > 0) k else 0;
    color.g = @intFromFloat((value - value * saturation * k) * 255);

    // Blue channel
    k = @mod(1.0 + hue, 6.0);
    t = 4 - k;
    k = if (t < k) t else k;
    k = if (k < 1) k else 1;
    k = if (k > 0) k else 0;
    color.b = @intFromFloat((value - value * saturation * k) * 255);

    return color;
}

fn drawChromaticWheel(framebuffer: *limine.Framebuffer) void {
    for (0..100) |x| {
        for (0..100) |y| {
            const fb_ptr: [*]volatile u32 = @ptrCast(@alignCast(framebuffer.address));
            const fy = @as(f64, @floatFromInt(y));
            const fx = @as(f64, @floatFromInt(x));
            const s = @sqrt(math.pow(f64, fx - 50, 2) + math.pow(f64, fy - 50, 2)) / 50.0;
            if (s <= 1.0) {
                var angle = math.atan2(fy - 50.0, fx - 50.0) + (math.pi / 2.0);
                if (angle < 0) angle += 2 * math.pi;
                const h = angle;
                const color = from_hsv(h, s, 1.0);
                fb_ptr[y * (framebuffer.pitch / 4) + x] = color.r * 256 * 256 + color.g * 256 + color.b;
            }
        }
    }
}
