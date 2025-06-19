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
    const Vec4 = vec.Vec4(f32);
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

        // need to query this later for proper scale rendering
        var terminal_info: uti.TerminalInfo = undefined;
        terminal_info.char_apsect = 1.3; // height x width of the terminal character
        terminal_info.screen_aspect = 2800.0 / 1080.0; // width x height of the terminal screen
        terminal_info.render_freq = 5;

        return Renderer{
            .main = try uti.Buffer(Color).init(width, height, allocator, Color.build(35, 35, 55)),
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

        const vertices = [_]Vec3{
            Vec3.build(-0.35, -0.55, 0.0),
            Vec3.build(0.27, -0.42, 0.0),
            Vec3.build(-0.05, 0.55, 0.0),
        };
        _ = self.worldToViewSpace(&simulation.player, vertices[0]);
        self.renderTriangle(&vertices);
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
                const color = self.main.get(x, y).?;
                try writer.print("\x1b[48;2;{};{};{}m ", .{ color.x, color.y, color.z });
            }
            try writer.writeByte('\n');
        }
        try writer.writeAll("\x1b[0m");
        try writer.writeAll("\x1b[?25h");

        try buffer_writer.flush();
    }

    fn renderTriangle(self: *Self, triangle: *const [3]Vec3) void {
        const screen_a, const screen_b, const screen_c = .{
            self.NDCToScreenSpace(triangle[0]),
            self.NDCToScreenSpace(triangle[1]),
            self.NDCToScreenSpace(triangle[2]),
        };

        const a_signed, const b_signed, const c_signed = .{
            vec.Vec2(i32).build(@intCast(screen_a.x), @intCast(screen_a.y)),
            vec.Vec2(i32).build(@intCast(screen_b.x), @intCast(screen_b.y)),
            vec.Vec2(i32).build(@intCast(screen_c.x), @intCast(screen_c.y)),
        };

        const tri_min, const tri_max = triangleBounds(screen_a, screen_b, screen_c);

        for (tri_min.x..tri_max.x) |x| {
            for (tri_min.y..tri_max.y) |y| {
                if (x >= self.width or y >= self.height) {
                    continue;
                }

                const inv = 1 / @as(f32, @floatFromInt(triangleEdge(a_signed, b_signed, c_signed)));
                const point = vec.Vec2(i32).build(@intCast(x), @intCast(y));

                const weight0, const weight1, const weight2 = .{
                    @as(f32, @floatFromInt(triangleEdge(a_signed, b_signed, point))) * inv,
                    @as(f32, @floatFromInt(triangleEdge(b_signed, c_signed, point))) * inv,
                    @as(f32, @floatFromInt(triangleEdge(c_signed, a_signed, point))) * inv,
                };

                const hue = 0.4;
                if (weight0 >= 0 and weight1 >= 0 and weight2 >= 0) {
                    var red = @as(u8, @intFromFloat(weight0 * 255));
                    red += @as(u8, @intFromFloat(weight1 * 255 * hue));
                    var green = @as(u8, @intFromFloat(weight1 * 255));
                    green += @as(u8, @intFromFloat(weight2 * 255 * hue));
                    var blue = @as(u8, @intFromFloat(weight2 * 255));
                    blue += @as(u8, @intFromFloat(weight0 * 255 * hue));

                    _ = self.main.set(x, y, Color.build(red, green, blue));
                }
            }
        }
    }

    fn worldToViewSpace(self: *Self, cam: *sim.Player, point: Vec3) Vec4 {
        _ = .{self};

        const matrix = cam.getViewMatrix();
        const point4 = Vec4.fromVec3Homogenous(point);

        return matrix.mulVec(point4);
    }

    fn NDCToScreenSpace(self: *Self, ndc: Vec3) vec.Vec2(usize) {
        const half_width, const half_height = self.halfDimensionsFloat();

        const floatx, const floaty = .{
            ndc.x * half_width + half_width,
            -ndc.y * half_height + half_height,
        };

        const x: usize, const y: usize = .{
            @intFromFloat(floatx),
            @intFromFloat(floaty),
        };

        return vec.Vec2(usize).build(x, y);
    }

    fn halfDimensionsFloat(self: *Self) struct { f32, f32 } {
        return .{ @as(f32, @floatFromInt(self.width)) / 2, @as(f32, @floatFromInt(self.height)) / 2 };
    }
};

pub fn triangleBounds(a: vec.Vec2(usize), b: vec.Vec2(usize), c: vec.Vec2(usize)) struct {
    vec.Vec2(usize),
    vec.Vec2(usize),
} {
    const max_x = @max(a.x, b.x, c.x);
    const min_x = @min(a.x, b.x, c.x);
    const max_y = @max(a.y, b.y, c.y);
    const min_y = @min(a.y, b.y, c.y);

    return .{ vec.Vec2(usize).build(min_x, min_y), vec.Vec2(usize).build(max_x, max_y) };
}

pub fn triangleEdge(a: vec.Vec2(i32), b: vec.Vec2(i32), c: vec.Vec2(i32)) i32 {
    return (c.x - a.x) * (b.y - a.y) - (c.y - a.y) * (b.x - a.x);
}

const Triangle = struct {
    a: Vec3,
    b: Vec3,
    c: Vec3,

    const Self = @This();
    const Vec3 = vec.Vec3(f32);
};
