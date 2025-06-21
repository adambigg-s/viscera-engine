const lib = @import("../root.zig");
const std = lib.std;
const sim = lib.sim;
const vec = lib.vec;
const win = lib.win;
const uti = lib.uti;

pub const Renderer = struct {
    main: Buffer(Color),
    depth: Buffer(f32),
    width: usize,
    height: usize,
    terminal_info: uti.TerminalInfo,

    const Self = @This();
    const Alloc = std.mem.Allocator;
    const Vec2 = vec.Vec2(f32);
    const Vec3 = vec.Vec3(f32);
    const Vec4 = vec.Vec4(f32);
    const Color = vec.Vec3(u8);
    const Buffer = uti.Buffer;

    const infinity = 1e6;
    const epsilon = 1e-6;

    const math = std.math;

    pub fn init(allocator: Alloc) !Self {
        var width, var height = try win.getTerminalDimensionsChar();
        width, height = .{
            lib.nearestLowerOdd(usize, width),
            lib.nearestLowerOdd(usize, height),
        };

        // need to query this later for proper scale rendering
        var terminal_info: uti.TerminalInfo = undefined;
        terminal_info.char_apsect = 1.3; // height x width of the terminal character
        terminal_info.screen_aspect = 2800.0 / 1080.0; // width x height of the terminal screen

        return Renderer{
            .main = try Buffer(Color).init(width, height, allocator, Color.build(35, 35, 55)),
            .depth = try Buffer(f32).init(width, height, allocator, Self.infinity),
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
        var pixel_brush = Color.zeros();
        for (0..self.height) |y| {
            for (0..self.width) |x| {
                const color = self.main.get(x, y) orelse unreachable;
                if (std.meta.eql(pixel_brush, color)) {
                    try writer.writeByte(' ');
                } else {
                    try writer.print("\x1b[48;2;{};{};{}m ", .{ color.x, color.y, color.z });
                    pixel_brush = color;
                }
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
