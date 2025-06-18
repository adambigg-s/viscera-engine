const lib = @import("../root.zig");
const std = lib.std;
const sim = lib.sim;
const vec = lib.vec;
const win = lib.win;
const uti = lib.uti;

pub const Renderer = struct {
    main: uti.Buffer(Color),
    depth: uti.Buffer(f32),
    width: usize,
    height: usize,
    terminal_info: uti.TerminalInfo,

    const Self = @This();
    const Alloc = std.mem.Allocator;
    const Vec3 = vec.Vec3(f32);
    const Color = vec.Vec3(u8);

    const infinity = 1e9;
    const epsilon = 1e-9;

    const math = std.math;

    pub fn init(allocator: Alloc) !Self {
        var width, var height = try win.getTerminalDimensionsChar();
        // makes sure the crosshair is actually in the center
        width, height = .{
            lib.nearestLowerOdd(usize, width),
            lib.nearestLowerOdd(usize, height),
        };
        const braille_width, const braille_height = .{ width * uti.Braille.width, height * uti.Braille.height };

        // need to query this later for proper scale rendering
        var terminal_info: uti.TerminalInfo = undefined;
        terminal_info.char_apsect = 1.3; // height x width of the terminal character
        terminal_info.screen_aspect = 2800.0 / 1080.0; // width x height of the terminal screen
        terminal_info.render_freq = 5;

        return Renderer{
            .main = try uti.Buffer(Color).init(braille_width, braille_height, allocator, Color.build(20, 20, 80)),
            .depth = try uti.Buffer(f32).init(width, height, allocator, Self.infinity),
            .width = width,
            .height = height,
            .terminal_info = terminal_info,
        };
    }

    pub fn deinit(self: *Self) void {
        self.main.deinit();
        self.depth.deinit();
    }

    pub fn clear(self: *Self) void {
        self.main.clear();
        self.depth.clear();
    }

    pub fn renderSimulation(self: *Self, simulation: *sim.Simulation) void {
        _ = .{ self, simulation };
    }

    pub fn commitPass(self: *Self) !void {
        var stdout = std.io.getStdOut();
        var buffer_writer = std.io.bufferedWriter(stdout.writer());
        const writer = buffer_writer.writer();

        try writer.writeAll("\x1b[H");
        try writer.writeAll("\x1b[48;2;110;110;110m");
        try writer.writeAll("\x1b[?25l");
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                _ = .{ x, y };
                // const data = self.main.get(x, y).?;
                // var char_buffer: [3]u8 = undefined;
                // // this is a really weird conversion but it shouldn't ever panic
                // // 3 * 8 > 21 so it should always be a big enough buffer
                // const len = try std.unicode.utf8Encode(@intCast(data), &char_buffer);
                // try writer.writeAll(char_buffer[0..len]);
            }
            try writer.writeByte('\n');
        }
        try writer.writeAll("\x1b[0m");
        try writer.writeAll("\x1b[?25h");

        try buffer_writer.flush();
    }

    fn halfDimensionsFloat(self: *Self) struct { f32, f32 } {
        return .{ @as(f32, @floatFromInt(self.width)) / 2, @as(f32, @floatFromInt(self.height)) / 2 };
    }
};
