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
        self.renderTrianglePoints(&simulation.player);
    }

    fn renderTrianglePoints(self: *Self, cam: *sim.Player) void {
        const ar = self.terminal_info.screen_aspect;

        const proj = cam.getProjectionMatrix(ar);
        const view = cam.getViewMatrix();

        const tri = [_]Vec3{
            Vec3.build(-0.5, -0.5, -2.0),
            Vec3.build(0.5, -0.5, -2.0),
            Vec3.build(0.0, 0.5, -2.0),
        };

        for (tri) |point| {
            const world = Vec4.fromVec3Homogenous(point);
            const view_pos = view.mulVec(world);
            const clip_pos = proj.mulVec(view_pos);

            if (clip_pos.w < Self.epsilon) {
                continue;
            }

            const ndc = Vec3.build(clip_pos.x, clip_pos.y, clip_pos.z).div(clip_pos.w);

            if (!self.withinView(ndc)) {
                continue;
            }

            const screen = self.NDCToScreenSpace(ndc);
            _ = self.main.set(screen.x, screen.y, Color.build(255, 255, 255));
        }
    }

    fn withinView(self: *Self, point: Vec3) bool {
        _ = .{self};
        return point.x < 1 and point.x > -1 and point.y > -1 and point.y < 1;
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
