const lib = @import("root.zig");

pub fn main() !void {
    var general_allocator = lib.std.heap.DebugAllocator(.{}).init;
    defer lib.std.debug.print("allocator health status: {}", .{general_allocator.deinit()});
    const allocator = general_allocator.allocator();

    var app = lib.app.Application{
        .inputs = try lib.sim.Inputs.init(),
        .simulation = try lib.sim.Simulation.init(allocator),
        .renderer = try lib.ren.Renderer.init(allocator),
    };
    defer app.deinit();

    try app.run();

    // braille debugging
    {
        const braille_start: u21 = 0x2800;
        // var char: u8 = 0;
        // char |= 1 << lib.ren.Braille.bitmap[1][1];
        // const braille_char = braille_start + @as(u32, @intCast(char));
        const braille_char = braille_start + 255;

        var char_buffer: [4]u8 = undefined;
        const len = try lib.std.unicode.utf8Encode(@intCast(braille_char), &char_buffer);

        // for some reason this doesn't working with debug print, must use actual stdout handle
        var stdout = lib.std.io.getStdOut();
        var buffer_writer = lib.std.io.bufferedWriter(stdout.writer());
        const writer = buffer_writer.writer();

        try writer.writeAll("\x1b[44Hbraille char: ");
        try writer.writeAll(char_buffer[0..len]);
        try writer.writeByte('\n');
        try buffer_writer.flush();
    }
}
