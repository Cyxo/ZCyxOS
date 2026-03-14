const builtin = @import("builtin");
const limine = @import("limine");

const console = @import("screen/console.zig");
const font = @import("screen/font.zig");

export var start_marker: limine.RequestsStartMarker linksection(".limine_requests_start") = .{};
export var end_marker: limine.RequestsEndMarker linksection(".limine_requests_end") = .{};

export var base_revision: limine.BaseRevision linksection(".limine_requests") = .init(3);
export var framebuffer_request: limine.FramebufferRequest linksection(".limine_requests") = .{};

fn hcf() noreturn {
    while (true) {
        switch (builtin.cpu.arch) {
            .x86_64 => asm volatile ("hlt"),
            .aarch64 => asm volatile ("wfi"),
            .riscv64 => asm volatile ("wfi"),
            .loongarch64 => asm volatile ("idle 0"),
            else => unreachable,
        }
    }
}

export fn _start() callconv(.c) noreturn {
    kmain();

    // Loop forever as there is nothing to do
    hcf();
}

// We use noinline to make sure it don't get inlined by compiler
noinline fn kmain() callconv(.c) void {
    if (!base_revision.isSupported()) {
        @panic("Base revision not supported");
    }

    // Ensure we got a framebuffer.
    if (framebuffer_request.response) |response| {
        if (response.framebuffer_count >= 1) {
            const framebuffer: *limine.Framebuffer = response.getFramebuffers()[0];

            console.init(framebuffer);
            console.print("Hello from {s} v{d}!", .{ "CyxOS", 3 });
        } else {
            @panic("No framebuffer returned by Limine");
        }
    } else {
        @panic("Framebuffer response not present");
    }
}
