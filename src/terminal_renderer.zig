const lib = @import("root.zig");
const std = lib.std;
const sim = lib.sim;
const vec = lib.vec;
const win = lib.win;

pub const Frustum = struct {
    vertical_positive: FrustumPlane,
    horizontal_positive: FrustumPlane,
    vertical_negative: FrustumPlane,
    horizontal_negative: FrustumPlane,
};

pub const FrustumPlane = struct {
    axis: Axis3,
    coefficient: f32,

    pub const Axis3 = enum {
        X,
        Y,
        Z,
    };
};

// https://en.wikipedia.org/wiki/Braille_Patterns
pub const Braille = struct {
    pub const width = 2;
    pub const height = 4;
    pub const start = 0x2800;
    pub const count = Self.width * Self.height;
    pub const bitmap = [][]comptime_int{
        .{ 0, 3 },
        .{ 1, 4 },
        .{ 2, 5 },
        .{ 6, 7 },
    };

    const Self = @This();
};

pub const TerminalInfo = struct {
    screen_aspect: f32,
    char_apsect: f32,
    render_freq: usize,

    const Self = @This();

    pub fn shouldRender(self: *Self, tick: usize) bool {
        return 0 == tick % self.render_freq;
    }
};

pub fn Buffer(comptime T: type) type {
    return struct {
        width: usize,
        height: usize,
        data: std.ArrayList(T),
        clear_value: T,
        allocator: std.mem.Allocator,

        const Self = @This();
        const Alloc = std.mem.Allocator;

        pub fn init(width: usize, height: usize, allocator: Alloc, clear_value: T) !Self {
            var data = try std.ArrayList(T).initCapacity(allocator, width * height);
            data.expandToCapacity();
            var output = Buffer(T){
                .width = width,
                .height = height,
                .data = data,
                .clear_value = clear_value,
                .allocator = allocator,
            };
            output.clear();

            return output;
        }

        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }

        pub fn clear(self: *Self) void {
            @memset(self.data.items, self.clear_value);
        }

        pub fn get(self: *Self, x: usize, y: usize) ?T {
            if (!self.inbounds(x, y)) {
                return null;
            }

            return self.data.items[self.index(x, y)];
        }

        pub fn set(self: *Self, x: usize, y: usize, data: T) bool {
            if (!self.inbounds(x, y)) {
                return false;
            }

            self.data.items[self.index(x, y)] = data;
            return true;
        }

        fn index(self: *Self, x: usize, y: usize) usize {
            return self.width * y + x;
        }

        fn inbounds(self: *Self, x: usize, y: usize) bool {
            return x < self.width and y < self.height;
        }
    };
}

pub const Renderer = struct {
    main: Buffer(u21),
    braille: Buffer(u32),
    depth: Buffer(f32),
    width: usize,
    height: usize,
    terminal_info: TerminalInfo,

    const Self = @This();
    const Alloc = std.mem.Allocator;
    const Vec3 = vec.Vec3(f32);

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
        const braille_width, const braille_height = .{ width * Braille.width, height * Braille.height };

        // need to query this later for proper scale rendering
        var terminal_info: TerminalInfo = undefined;
        terminal_info.char_apsect = 1.3; // height x width of the terminal character
        terminal_info.screen_aspect = 2800.0 / 1080.0; // width x height of the terminal screen
        terminal_info.render_freq = 5;

        return Renderer{
            .main = try Buffer(u21).init(width, height, allocator, ' '),
            .braille = try Buffer(u32).init(braille_width, braille_height, allocator, Braille.start),
            .depth = try Buffer(f32).init(width, height, allocator, Self.infinity),
            .width = width,
            .height = height,
            .terminal_info = terminal_info,
        };
    }

    pub fn deinit(self: *Self) void {
        self.main.deinit();
        self.braille.deinit();
        self.depth.deinit();
    }

    pub fn clear(self: *Self) void {
        self.main.clear();
        self.braille.clear();
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
                const data = self.main.get(x, y).?;
                var char_buffer: [3]u8 = undefined;
                // this is a really weird conversion but it shouldn't ever panic
                // 3 * 8 > 21 so it should always be a big enough buffer
                const len = try std.unicode.utf8Encode(@intCast(data), &char_buffer);
                try writer.writeAll(char_buffer[0..len]);
            }
            try writer.writeByte('\n');
        }
        try writer.writeAll("\x1b[0m");
        try writer.writeAll("\x1b[?25h");

        try buffer_writer.flush();
    }

    fn renderBillboardCircle(self: *Self, viewmodel: *sim.Player, position: Vec3, size: f32, fill: u8) void {
        _ = .{ self, viewmodel, position, size, fill };
    }

    fn renderText(self: *Self, text: []const u8, start: vec.Vec2(usize)) void {
        var runner: usize = 0;
        var span: usize = 0;
        for (text) |char| {
            while (!self.main.set(start.x + runner, start.y + span, @intCast(char))) {
                runner = 0;
                span += 1;

                if (span > self.height) {
                    break;
                }
            }

            runner += 1;
        }
    }

    fn renderPoint(self: *Self, viewmodel: *sim.Player, position: Vec3, fill: u8) void {
        const viewspace = self.worldToViewspace(viewmodel, position);

        const ndc = self.viewspaceToNDC(viewmodel, viewspace);

        if (!self.isInView(viewmodel, ndc)) {
            return;
        }

        const screenspace = self.NDCToScreenspace(ndc);

        const unsigned_x: usize, const unsigned_y: usize = .{
            @bitCast(screenspace.x),
            @bitCast(screenspace.y),
        };
        _ = self.main.set(unsigned_x, unsigned_y, fill);
    }

    fn renderLineClipped(self: *Self, viewmodel: *sim.Player, a: Vec3, b: Vec3, fill: u8) void {
        var viewspace_a, var viewspace_b = .{
            self.worldToViewspace(viewmodel, a),
            self.worldToViewspace(viewmodel, b),
        };

        if (!self.clipDistancePlanes(&viewspace_a, &viewspace_b, viewmodel)) {
            return;
        }

        const frustum = self.makeFrustum(viewmodel);
        if (!self.clipLineToFrustum(&viewspace_a, &viewspace_b, frustum)) {
            return;
        }

        const ndc_a, const ndc_b = .{
            self.viewspaceToNDC(viewmodel, viewspace_a),
            self.viewspaceToNDC(viewmodel, viewspace_b),
        };

        const screenspace_a, const screenspace_b = .{
            self.NDCToScreenspace(ndc_a),
            self.NDCToScreenspace(ndc_b),
        };

        var tracer = LineTracer.build(screenspace_a.x, screenspace_a.y, screenspace_b.x, screenspace_b.y);
        while (tracer.next()) |point| {
            const unsigned_x: usize, const unsigned_y: usize = .{ @bitCast(point.x), @bitCast(point.y) };
            _ = self.main.set(unsigned_x, unsigned_y, fill);
        }
    }

    fn worldToViewspace(_: *Self, viewmodel: *sim.Player, point: Vec3) Vec3 {
        // takes care of translation
        const local = point.sub(viewmodel.pos);

        // cool direction cosine trick to take care of all rotations
        // https://moorepants.github.io/learn-multibody-dynamics/orientation.html
        return local.directionCosineVec(
            viewmodel.front,
            viewmodel.up,
            viewmodel.right,
        );
    }

    fn viewspaceToNDC(self: *Self, viewmodel: *sim.Player, viewspace: Vec3) Vec3 {
        // https://stackoverflow.com/questions/4427662/whats-the-relationship-between-field-of-view-and-lens-length
        const projection_coefficient_base = 1 / (math.tan(viewmodel.vertical_fov / 2) * viewspace.x);

        const projection_coefficients = self.terminalProjectionCorrection(projection_coefficient_base);

        // my references frames (for camera):
        //     x: depth
        //     y: up
        //     z: right
        // puts into NDC in screen-space basis
        return Vec3.build(
            viewspace.z * projection_coefficients.x,
            -viewspace.y * projection_coefficients.y,
            viewspace.x,
        );
    }

    fn NDCToScreenspace(self: *Self, ndc: Vec3) vec.Vec2(isize) {
        const half_width, const half_height = self.halfDimensionsFloat();

        const floatx, const floaty = .{
            ndc.x * half_width + half_width,
            ndc.y * half_height + half_height,
        };

        const xsigned: isize, const ysigned: isize = .{ @intFromFloat(floatx), @intFromFloat(floaty) };

        return vec.Vec2(isize).build(xsigned, ysigned);
    }

    fn isInView(_: *Self, viewmodel: *sim.Player, point: Vec3) bool {
        const viewx, const viewy, const viewz = .{
            point.x < 1 and point.x > -1,
            point.y < 1 and point.y > -1,
            point.z < viewmodel.far_plane and point.z > viewmodel.near_plane,
        };

        return viewx and viewy and viewz;
    }

    fn makeFrustum(self: *Self, viewmodel: *sim.Player) Frustum {
        var fov = viewmodel.vertical_fov;
        // slightly make fov smaller to clip in view of screen boundary
        if (@import("builtin").mode == .Debug) {
            fov = std.math.radiansToDegrees(fov) - 3;
            fov = std.math.degreesToRadians(fov);
        }

        const tan_half_fov = math.tan(fov / 2);
        const vertical_modifier = tan_half_fov * self.terminal_info.char_apsect;
        const horizontal_modifier = tan_half_fov * self.terminal_info.screen_aspect;

        return Frustum{
            .vertical_positive = FrustumPlane{
                .axis = FrustumPlane.Axis3.Y,
                .coefficient = vertical_modifier,
            },
            .horizontal_positive = FrustumPlane{
                .axis = FrustumPlane.Axis3.Z,
                .coefficient = horizontal_modifier,
            },
            .vertical_negative = FrustumPlane{
                .axis = FrustumPlane.Axis3.Y,
                .coefficient = -vertical_modifier,
            },
            .horizontal_negative = FrustumPlane{
                .axis = FrustumPlane.Axis3.Z,
                .coefficient = -horizontal_modifier,
            },
        };
    }

    fn clipDistancePlanes(_: *Self, a: *Vec3, b: *Vec3, viewmodel: *sim.Player) bool {
        if (a.x < viewmodel.near_plane and b.x < viewmodel.near_plane) {
            return false;
        }
        if (a.x < viewmodel.near_plane) {
            const time = (viewmodel.near_plane - a.x) / (b.x - a.x);
            a.* = lib.linearInterpolateVec3(a.*, b.*, time);
        }
        if (b.x < viewmodel.near_plane) {
            const time = (viewmodel.near_plane - b.x) / (a.x - b.x);
            b.* = lib.linearInterpolateVec3(b.*, a.*, time);
        }

        return true;
    }

    fn clipLineToFrustum(self: *Self, a: *Vec3, b: *Vec3, frustum: Frustum) bool {
        // https://chaosinmotion.com/2016/05/22/3d-clipping-in-homogeneous-coordinates/comment-page-1/
        // slightly faster way to clip lines in a software rasterizer, despite
        // looking much more complex this only uses 3D coordinate space so
        // we need to clip directly against the Euclidean geometrical frustum
        // without a homogenous coord

        // clipping against (up = -depth * vertical fov)
        if (!self.clipLineAgainstFrustumPlane(a, b, frustum.horizontal_negative)) {
            return false;
        }
        // clipping against (up = depth * vertical fov)
        if (!self.clipLineAgainstFrustumPlane(a, b, frustum.horizontal_positive)) {
            return false;
        }
        // clipping against (right = -depth * horizontal fov)
        if (!self.clipLineAgainstFrustumPlane(a, b, frustum.vertical_negative)) {
            return false;
        }
        // clipping against (right = depth * horizontal fov)
        if (!self.clipLineAgainstFrustumPlane(a, b, frustum.vertical_positive)) {
            return false;
        }

        return true;
    }

    fn clipLineAgainstFrustumPlane(_: *Self, a: *Vec3, b: *Vec3, frustumplane: FrustumPlane) bool {
        const axis, const coeff = .{ frustumplane.axis, frustumplane.coefficient };

        const a_val = switch (axis) {
            FrustumPlane.Axis3.Y => a.y,
            FrustumPlane.Axis3.Z => a.z,
            else => unreachable,
        };
        const b_val = switch (axis) {
            FrustumPlane.Axis3.Y => b.y,
            FrustumPlane.Axis3.Z => b.z,
            else => unreachable,
        };

        const a_plane, const b_plane = .{ coeff * a.x, coeff * b.x };

        const a_inside = if (coeff > 0) a_val <= a_plane else a_val >= a_plane;
        const b_inside = if (coeff > 0) b_val <= b_plane else b_val >= b_plane;
        if (a_inside and b_inside) {
            return true;
        }
        if (!a_inside and !b_inside) {
            return false;
        }

        if (!a_inside) {
            const time = (a_val - coeff * a.x) / ((a_val - coeff * a.x) - (b_val - coeff * b.x));
            if (time >= 0 and time <= 1) {
                a.* = lib.linearInterpolateVec3(a.*, b.*, time);
            }
        }
        if (!b_inside) {
            const time = (b_val - coeff * b.x) / ((b_val - coeff * b.x) - (a_val - coeff * a.x));
            if (time >= 0 and time <= 1) {
                b.* = lib.linearInterpolateVec3(b.*, a.*, time);
            }
        }

        return true;
    }

    fn terminalProjectionCorrection(self: *Self, raw_coefficient: f32) vec.Vec2(f32) {
        return vec.Vec2(f32).build(
            raw_coefficient / self.terminal_info.screen_aspect,
            raw_coefficient / self.terminal_info.char_apsect,
        );
    }

    fn halfDimensionsFloat(self: *Self) struct { f32, f32 } {
        return .{ @as(f32, @floatFromInt(self.width)) / 2, @as(f32, @floatFromInt(self.height)) / 2 };
    }
};

// https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
pub const LineTracer = struct {
    x0: isize,
    y0: isize,
    x1: isize,
    y1: isize,
    dx: isize,
    dy: isize,
    sx: isize,
    sy: isize,
    err: isize,
    done: bool,

    const Self = @This();

    pub fn build(x0: isize, y0: isize, x1: isize, y1: isize) Self {
        var dx: isize, var dy: isize = .{
            x1 - x0,
            y1 - y0,
        };
        dx, dy = .{
            @as(isize, @intCast(@abs(dx))),
            @as(isize, @intCast(@abs(dy))) * -1,
        };

        const sx: isize, const sy: isize = .{
            if (x0 < x1) 1 else -1,
            if (y0 < y1) 1 else -1,
        };

        const err = dx + dy;

        return LineTracer{
            .x0 = x0,
            .y0 = y0,
            .x1 = x1,
            .y1 = y1,
            .dx = dx,
            .dy = dy,
            .sx = sx,
            .sy = sy,
            .err = err,
            .done = false,
        };
    }

    pub fn next(self: *Self) ?vec.Vec2(isize) {
        if (self.done) return null;
        const point = vec.Vec2(isize).build(self.x0, self.y0);

        const err2 = 2 * self.err;

        if (err2 >= self.dy) {
            if (self.x1 == self.x0) {
                self.done = true;
            }
            self.err += self.dy;
            self.x0 += self.sx;
        }

        if (err2 <= self.dx) {
            if (self.y1 == self.y0) {
                self.done = true;
            }
            self.err += self.dx;
            self.y0 += self.sy;
        }

        return point;
    }
};

// strictly for debugging at this point - more efficient one added later
pub const Box3 = struct {
    min: Vec3,
    max: Vec3,

    const Self = @This();
    const Vec3 = vec.Vec3(f32);

    pub fn build(min: Vec3, max: Vec3) Self {
        return Box3{ .min = min, .max = max };
    }

    pub fn toLinestrip(self: *Self) [24][3]f32 {
        var output: [24][3]f32 = undefined;

        const min, const max = .{ self.min, self.max };

        const corners: [8][3]f32 = .{
            .{ min.x, min.y, min.z },
            .{ max.x, min.y, min.z },
            .{ max.x, max.y, min.z },
            .{ min.x, max.y, min.z },
            .{ min.x, min.y, max.z },
            .{ max.x, min.y, max.z },
            .{ max.x, max.y, max.z },
            .{ min.x, max.y, max.z },
        };

        const indices: [12][2]usize = .{
            .{ 0, 1 }, .{ 1, 2 }, .{ 2, 3 }, .{ 3, 0 },
            .{ 4, 5 }, .{ 5, 6 }, .{ 6, 7 }, .{ 7, 4 },
            .{ 0, 4 }, .{ 1, 5 }, .{ 2, 6 }, .{ 3, 7 },
        };

        for (indices, 0..indices.len) |pair, index| {
            output[index * 2 + 0] = corners[pair[0]];
            output[index * 2 + 1] = corners[pair[1]];
        }

        return output;
    }
};
