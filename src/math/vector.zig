const lib = @import("../root.zig");
const std = lib.std;
const math = std.math;

pub fn Vec2(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,

        const Self = @This();

        pub fn build(x: T, y: T) Self {
            return Self{ .x = x, .y = y };
        }

        pub fn zeros() Self {
            return Self.build(0, 0);
        }

        pub fn splat(value: T) Self {
            return Self.build(value, value);
        }

        pub fn neg(self: Self) Self {
            return Self.build(-self.x, -self.y);
        }

        pub fn add(self: Self, other: Self) Self {
            return Self.build(self.x + other.x, self.y + other.y);
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self.build(self.x - other.x, self.y - other.y);
        }

        pub fn mul(self: Self, scalar: T) Self {
            return Self.build(self.x * scalar, self.y * scalar);
        }

        pub fn div(self: Self, scalar: T) Self {
            const inv = 1 / scalar;
            return Self.build(self.x * inv, self.y * inv);
        }

        pub fn innerProduct(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y;
        }

        pub fn crossProduct(self: Self, other: Self) T {
            return self.x * other.y - self.y * other.x;
        }

        pub fn lengthSq(self: Self) T {
            return self.innerProduct(self);
        }

        pub fn length(self: Self) T {
            return math.sqrt(self.lengthSq());
        }

        pub fn normalize(self: Self) Self {
            return self.div(self.length());
        }

        pub fn mulComponent(self: Self, other: Self) Self {
            return Self.build(self.x * other.x, self.y * other.y);
        }
    };
}

pub fn Vec3(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,
        z: T = 0,

        const Self = @This();

        pub fn build(x: T, y: T, z: T) Self {
            return Self{ .x = x, .y = y, .z = z };
        }

        pub fn zeros() Self {
            return Self.build(0, 0, 0);
        }

        pub fn splat(value: T) Self {
            return Self.build(value, value, value);
        }

        pub fn neg(self: Self) Self {
            return Self.build(-self.x, -self.y, -self.z);
        }

        pub fn add(self: Self, other: Self) Self {
            return Self.build(self.x + other.x, self.y + other.y, self.z + other.z);
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self.build(self.x - other.x, self.y - other.y, self.z - other.z);
        }

        pub fn mul(self: Self, scalar: T) Self {
            return Self.build(self.x * scalar, self.y * scalar, self.z * scalar);
        }

        pub fn div(self: Self, scalar: T) Self {
            const inv = 1 / scalar;
            return Self.build(self.x * inv, self.y * inv, self.z * inv);
        }

        pub fn innerProduct(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y + self.z * other.z;
        }

        pub fn crossProduct(self: Self, other: Self) Self {
            return Self.build(
                self.y * other.z - self.z * other.y,
                -(self.x * other.z - self.z * other.x),
                self.x * other.y - self.y * other.x,
            );
        }

        pub fn lengthSq(self: Self) T {
            return self.innerProduct(self);
        }

        pub fn length(self: Self) T {
            return math.sqrt(self.lengthSq());
        }

        pub fn rotateX(self: Self, angle: T) Self {
            const sin, const cos = .{ math.sin(angle), math.cos(angle) };

            return Self.build(
                self.x,
                self.y * cos + self.z * -sin,
                self.y * sin + self.z * cos,
            );
        }

        pub fn rotateY(self: Self, angle: T) Self {
            const sin, const cos = .{ math.sin(angle), math.cos(angle) };

            return Self.build(
                self.x * cos + self.z * sin,
                self.y,
                self.x * -sin + self.z * cos,
            );
        }

        pub fn rotateZ(self: Self, angle: T) Self {
            const sin, const cos = .{ math.sin(angle), math.cos(angle) };

            return Self.build(
                self.x * cos + self.y * -sin,
                self.x * sin + self.y * cos,
                self.z,
            );
        }

        pub fn rotateXYZ(self: Self, angles: Self) Self {
            return self.rotateX(angles.x).rotateY(angles.y).rotateZ(angles.z);
        }

        pub fn rotateZYX(self: Self, angles: Self) Self {
            return self.rotateZ(angles.z).rotateY(angles.y).rotateX(angles.x);
        }

        pub fn normalize(self: Self) Self {
            return self.div(self.length());
        }

        pub fn mulComponent(self: Self, other: Self) Self {
            return Self.build(self.x * other.x, self.y * other.y, self.z * other.z);
        }

        pub fn directionCosineVec(self: Self, xp: Self, yp: Self, zp: Self) Self {
            return Self.build(
                self.innerProduct(xp),
                self.innerProduct(yp),
                self.innerProduct(zp),
            );
        }
    };
}

pub fn Vec4(comptime T: type) type {
    return struct {
        x: T = 0,
        y: T = 0,
        z: T = 0,
        w: T = 0,

        const Self = @This();

        pub fn build(x: T, y: T, z: T, w: T) Self {
            return Self{ .x = x, .y = y, .z = z, .w = w };
        }

        pub fn zeros() Self {
            return Self.build(0, 0, 0, 0);
        }

        pub fn splat(value: T) Self {
            return Self.build(value, value, value, value);
        }

        pub fn fromVec3(vec: Vec3(T), w: T) Self {
            return Self.build(vec.x, vec.y, vec.z, w);
        }

        pub fn fromVec3Homogenous(vec: Vec3(T)) Self {
            return Self.build(vec.x, vec.y, vec.z, 1);
        }

        pub fn neg(self: Self) Self {
            return Self.build(-self.x, -self.y, -self.y, -self.w);
        }

        pub fn add(self: Self, other: Self) Self {
            return Self.build(self.x + other.x, self.y + other.y, self.z + other.z, self.w + other.w);
        }

        pub fn sub(self: Self, other: Self) Self {
            return Self.build(self.x - other.x, self.y - other.y, self.z - other.z, self.w - other.w);
        }

        pub fn mul(self: Self, scalar: T) Self {
            return Self.build(self.x * scalar, self.y * scalar, self.z * scalar, self.w * scalar);
        }

        pub fn div(self: Self, scalar: T) Self {
            const inv = 1 / scalar;
            return Self.build(self.x * inv, self.y * inv, self.z * inv, self.w * inv);
        }

        pub fn innerProduct(self: Self, other: Self) T {
            return self.x * other.x + self.y * other.y + self.z * other.z + self.w * other.w;
        }

        pub fn lengthSq(self: Self) T {
            return self.innerProduct(self);
        }

        pub fn length(self: Self) T {
            return math.sqrt(self.lengthSq());
        }

        pub fn normalize(self: Self) Self {
            return self.div(self.length());
        }

        pub fn mulComponent(self: Self, other: Self) Self {
            return Self.build(self.x * other.x, self.y * other.y, self.z * other.z, self.w * other.w);
        }
    };
}

pub fn VecN(comptime T: type, comptime N: usize) type {
    return struct {
        inner: [N]T,

        pub const dim = N;

        const Self = @This();

        pub fn build(array: []const T) Self {
            std.debug.assert(array.len == Self.dim);

            var inner: [Self.dim]T = undefined;
            for (array, 0..) |value, i| {
                inner[i] = value;
            }

            return Self{ .inner = inner };
        }

        pub fn zeros() Self {
            comptime var inner: [Self.dim]T = undefined;
            comptime {
                for (0..Self.dim) |i| {
                    inner[i] = 0;
                }
            }

            return Self{ .inner = inner };
        }

        pub fn splat(value: T) Self {
            return Self.build(&[_]T{value} ** Self.dim);
        }

        pub fn neg(self: Self) Self {
            var result: [N]T = undefined;
            for (self.inner, 0..) |val, i| {
                result[i] = -val;
            }

            return Self{ .inner = result };
        }

        pub fn add(self: Self, other: Self) Self {
            std.debug.assert(self.inner.len == other.inner.len);

            var result: [N]T = undefined;
            for (self.inner, 0..) |val, i| {
                result[i] = val + other.inner[i];
            }

            return Self{ .inner = result };
        }

        pub fn sub(self: Self, other: Self) Self {
            std.debug.assert(self.inner.len == other.inner.len);

            var result: [N]T = undefined;
            for (self.inner, 0..) |val, i| {
                result[i] = val - other.inner[i];
            }

            return Self{ .inner = result };
        }

        pub fn mul(self: Self, scalar: T) Self {
            var result: [N]T = undefined;
            for (self.inner, 0..) |val, i| {
                result[i] = val * scalar;
            }

            return Self{ .inner = result };
        }

        pub fn div(self: Self, scalar: T) Self {
            var result: [N]T = undefined;
            const inv = 1 / scalar;
            for (self.inner, 0..) |val, i| {
                result[i] = val * inv;
            }

            return Self{ .inner = result };
        }

        pub fn innerProduct(self: Self, other: Self) T {
            std.debug.assert(self.inner.len == other.inner.len);

            var result: T = 0;
            for (self.inner, 0..) |val, i| {
                result += val * other.inner[i];
            }

            return result;
        }

        pub fn lengthSq(self: Self) T {
            return self.innerProduct(self);
        }

        pub fn length(self: Self) T {
            return math.sqrt(self.lengthSq());
        }

        pub fn normalize(self: Self) Self {
            return self.div(self.length());
        }

        pub fn mulComponent(self: Self, other: Self) Self {
            var result: [N]T = undefined;
            for (self.inner, 0..) |val, i| {
                result[i] = val * other.inner[i];
            }

            return Self{ .inner = result };
        }
    };
}

test "vec-n testing" {
    const vecn = VecN(f32, 4).build(&[_]f32{ 10, 10, 10, 10 });
    std.debug.print("vecn: {}\n", .{vecn});

    const vecn1 = VecN(f32, 2).splat(1);
    std.debug.print("vecn splat: {}\n", .{vecn1});

    const vecn2 = VecN(f32, 5).build(&[_]f32{ 100, 0, 0, 0, 0 });
    std.debug.print("vecn splat: {}\nlength: {}", .{ vecn2, vecn2.length() });
    try std.testing.expect(vecn2.length() == 100);
}
