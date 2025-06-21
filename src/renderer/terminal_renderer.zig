const lib = @import("../root.zig");
const std = lib.std;
const sim = lib.sim;
const vec = lib.vec;
const mat = lib.mat;
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

    const Self = @This();
    const Vec2 = vec.Vec2(f32);
    const BoundingBox = uti.BoundingBox(i32);

    pub fn build(v0: Vertex, v1: Vertex, v2: Vertex) Self {
        return Tri{ .verts = .{ v0, v1, v2 } };
    }

    pub fn boundingBox(self: *const Self) BoundingBox {
        const v0, const v1, const v2 = self.verts;
        const minx: i32 = @intFromFloat(@min(v0.pos.x, v1.pos.x, v2.pos.x));
        const maxx: i32 = @intFromFloat(@max(v0.pos.x, v1.pos.x, v2.pos.x));
        const miny: i32 = @intFromFloat(@min(v0.pos.y, v1.pos.y, v2.pos.y));
        const maxy: i32 = @intFromFloat(@max(v0.pos.y, v1.pos.y, v2.pos.y));

        return BoundingBox{
            .min = vec.Vec2(i32).build(minx, miny),
            .max = vec.Vec2(i32).build(maxx, maxy),
        };
    }

    pub fn barycentricSystem(self: *const Self) BarycentricSystem {
        const v0, const v1, const v2 = self.verts;

        return BarycentricSystem{
            .a = Vec2.swizzleVec3(v0.pos),
            .b = Vec2.swizzleVec3(v1.pos),
            .c = Vec2.swizzleVec3(v2.pos),
        };
    }
};

pub fn intColorFromFloat(color: vec.Vec3(f32)) vec.Vec3(u8) {
    return vec.Vec3(u8).build(
        @intFromFloat(color.x * 255),
        @intFromFloat(color.y * 255),
        @intFromFloat(color.z * 255),
    );
}

pub const BarycentricSystem = struct {
    a: Vec2,
    b: Vec2,
    c: Vec2,

    const Self = @This();
    const Vec2 = vec.Vec2(f32);
    const Vec3 = vec.Vec3(f32);

    pub fn calculate(self: *const Self, point: Vec2) Vec3 {
        const ab, const bc, const ca = .{
            self.b.sub(self.a),
            self.c.sub(self.b),
            self.a.sub(self.c),
        };
        const ap, const bp, const cp = .{
            point.sub(self.a),
            point.sub(self.b),
            point.sub(self.c),
        };
        const apb, const bpc, const cpa = .{
            ab.crossProduct(ap),
            bc.crossProduct(bp),
            ca.crossProduct(cp),
        };
        const total_area = apb + bpc + cpa;

        return Vec3.build(apb, bpc, cpa).div(total_area);
    }

    pub fn withinTriangle(self: *const Self, weights: Vec3) bool {
        _ = .{self};

        return weights.x >= 0 and weights.y >= 0 and weights.z >= 0;
    }
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
    const Mat3 = mat.Mat3(f32);
    const Mat4 = mat.Mat4(f32);
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
        const view_mat = simulation.player.getViewMatrix();
        const proj_mat = simulation.player.getProjectionMatrix(self.terminal_info.augmentedAR());

        const vertex0 = Vertex.build(Vec3.build(-0.5, -0.5, -2), ColFloat.build(0, 0, 0));
        const vertex1 = Vertex.build(Vec3.build(0.5, -0.5, -2), ColFloat.build(1, 0, 0));
        const vertex2 = Vertex.build(Vec3.build(-0.5, 0.5, -2), ColFloat.build(0, 0, 0));
        const vertex3 = Vertex.build(Vec3.build(0.5, -0.5, -2), ColFloat.build(0, 1, 0));
        const vertex4 = Vertex.build(Vec3.build(-0.5, 0.5, -2), ColFloat.build(0, 0, 0));
        const vertex5 = Vertex.build(Vec3.build(0.5, 0.5, -2), ColFloat.build(0, 0, 0));

        const tri1 = Tri.build(vertex0, vertex1, vertex2);
        const tri2 = Tri.build(vertex3, vertex4, vertex5);
        self.renderTriangle(tri1, view_mat, proj_mat);
        self.renderTriangle(tri2, view_mat, proj_mat);
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

    fn renderTriangle(self: *Self, triangle: Tri, view: Mat4, projection: Mat4) void {
        var screen_vertices: [3]?Vertex = .{null} ** 3;

        for (triangle.verts, 0..) |vertex, index| {
            if (self.worldToNDC(vertex, view, projection)) |ndc_vertex| {
                const screen_space = self.NDCToScreenSpace(ndc_vertex.pos);
                screen_vertices[index] = Vertex.build(screen_space, vertex.color);
            }
        }

        const v0, const v1, const v2 = .{
            screen_vertices[0] orelse return,
            screen_vertices[1] orelse return,
            screen_vertices[2] orelse return,
        };
        const screenspace_tri = Tri.build(v0, v1, v2);

        self.rasterizeTriangle(screenspace_tri);
    }

    fn rasterizeTriangle(self: *Self, triangle: Tri) void {
        const triangle_bounds = triangle.boundingBox();
        const v0, const v1, const v2 = triangle.verts;
        const barycentric_system = triangle.barycentricSystem();

        var y = triangle_bounds.min.y;
        while (y <= triangle_bounds.max.y) : (y += 1) {
            var x = triangle_bounds.min.x;
            while (x <= triangle_bounds.max.x) : (x += 1) {
                const point = Vec2.build(@floatFromInt(x), @floatFromInt(y));

                const barycentric_weights = barycentric_system.calculate(point);

                if (!barycentric_system.withinTriangle(barycentric_weights)) {
                    continue;
                }

                const color = Mat3.buildColumnsFromVec(
                    v0.color,
                    v1.color,
                    v2.color,
                );
                const pixel_color = color.mulVec(barycentric_weights);

                _ = self.main.set(@intCast(x), @intCast(y), intColorFromFloat(pixel_color));
            }
        }
    }

    fn debugRenderPoint(self: *Self, point: Vertex, view: Mat4, projection: Mat4) void {
        const ndc = self.worldToNDC(point, view, projection) orelse return;
        const screen_space = self.NDCToScreenSpace(ndc.pos);

        _ = self.main.set(
            @intFromFloat(screen_space.x),
            @intFromFloat(screen_space.y),
            ColInt.build(255, 0, 0),
        );
    }

    fn worldToNDC(self: *Self, world_space: Vertex, view: Mat4, projection: Mat4) ?Vertex {
        const view_space = view.mulVec(Vec4.fromVec3Homogenous(world_space.pos));
        const clip_space = projection.mulVec(view_space);

        if (clip_space.w < Self.epsilon) {
            return null;
        }

        const ndc = Vec3.swizzleVec4(clip_space).div(clip_space.w);

        if (!self.withinViewFrustum(ndc)) {
            return null;
        }

        return Vertex.build(ndc, world_space.color);
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
