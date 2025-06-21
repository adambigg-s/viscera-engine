const lib = @import("../root.zig");
const std = lib.std;
const sim = lib.sim;
const vec = lib.vec;
const win = lib.win;
const uti = lib.uti;

pub const Vertex = struct {
    pos: Vec3,
    color: Vec3,

    const Self = @This();
    const Vec3 = vec.Vec3(f32);

    pub fn build(pos: Vec3, color: Vec3) Self {
        return Vertex{ .pos = pos, .color = color };
    }
};

pub const Tri = struct {
    verts: [3]Vertex,
};

pub const Renderer = struct {
    main: Buffer(ColInt),
    depth: Buffer(f32),
    width: usize,
    height: usize,
    terminal_info: uti.TerminalInfo,

    const Self = @This();
    const Alloc = std.mem.Allocator;
    const Vec2 = vec.Vec2(f32);
    const Vec3 = vec.Vec3(f32);
    const Vec4 = vec.Vec4(f32);
    const ColInt = vec.Vec3(u8);
    const ColFloat = Vec3;
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
            .main = try Buffer(ColInt).init(width, height, allocator, ColInt.build(35, 35, 55)),
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

        const vertex = Vertex.build(Vec3.build(0, 0, -2), ColFloat.build(1, 0, 0));
        const view_mat = simulation.player.getViewMatrix();
        const proj_mat = simulation.player.getProjectionMatrix(self.terminal_info.screen_aspect);

        const worldspace = Vec4.fromVec3Homogenous(vertex.pos);
        const viewspace = view_mat.mulVec(worldspace);
        const clipspace = proj_mat.mulVec(viewspace);

        if (clipspace.w < Self.epsilon) return;

        const ndc = Vec3.swizzleVec4(clipspace).div(clipspace.w);

        if (!self.withinViewFrustum(ndc)) return;

        const screenspace = self.NDCToScreenSpace(ndc);

        _ = self.main.set(
            @intFromFloat(screenspace.x),
            @intFromFloat(screenspace.y),
            ColInt.build(255, 0, 0),
        );
    }

    pub fn commitPass(self: *Self) !void {
        var stdout = std.io.getStdOut();
        var buffer_writer = std.io.bufferedWriter(stdout.writer());
        const writer = buffer_writer.writer();

        try writer.writeAll("\x1b[H");
        try writer.writeAll("\x1b[?25l");
        var pixel_brush = ColInt.zeros();
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

    fn NDCToScreenSpace(self: *Self, ndc: Vec3) Vec3 {
        const half_width, const half_height = self.halfDimensionsFloat();

        const x, const y = .{
            ndc.x * half_width + half_width,
            -ndc.y * half_height + half_height,
        };

        return Vec3.build(x, y, ndc.z);
    }

    fn withinViewFrustum(_: *Self, ndc: Vec3) bool {
        const x, const y, const z = .{
            ndc.x <= 1 and ndc.x >= -1,
            ndc.y <= 1 and ndc.y >= -1,
            ndc.z <= 1 and ndc.z >= -1,
        };

        return x and y and z;
    }

    fn halfDimensionsFloat(self: *Self) struct { f32, f32 } {
        return .{ @as(f32, @floatFromInt(self.width)) / 2, @as(f32, @floatFromInt(self.height)) / 2 };
    }
};
