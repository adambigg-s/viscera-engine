const lib = @import("../root.zig");
const std = lib.std;
const vec = lib.vec;

pub fn BoundingBox(comptime T: type) type {
    return struct {
        min: Vec2,
        max: Vec2,

        const Self = @This();
        const Vec2 = vec.Vec2(T);
    };
}

pub const TerminalInfo = struct {
    screen_aspect: f32,
    char_apsect: f32,

    const Self = @This();

    pub fn augmentedAR(self: *Self) f32 {
        return self.screen_aspect / self.char_apsect;
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
