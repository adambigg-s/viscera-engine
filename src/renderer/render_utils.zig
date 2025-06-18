const lib = @import("../root.zig");
const std = lib.std;
const vec = lib.vec;

pub const Braille = struct {
    // https://en.wikipedia.org/wiki/Braille_Patterns
    pub const width = 2;
    pub const height = 4;
    pub const start = 0x2800;
    pub const count = Self.width * Self.height;
    pub const bitmap: [4][2]comptime_int = .{
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
