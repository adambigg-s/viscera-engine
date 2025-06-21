const lib = @import("../root.zig");
const std = lib.std;
const vec = lib.vec;
const math = std.math;

pub fn Mat2(comptime T: type) type {
    return struct {
        inner: [Self.dim][Self.dim]T,

        pub const dim = 2;

        const Self = @This();

        pub fn identity() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = if (i == j) 1 else 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn zeros() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn mulVec(self: *const Self, vector: vec.Vec2(T)) vec.Vec2(T) {
            const m = self.inner;
            const v = vector;

            return vec.Vec3(T).build(
                m[0][0] * v.x + m[0][1] * v.y,
                m[1][0] * v.x + m[1][1] * v.y,
            );
        }

        pub fn mulMat(self: *const Self, other: *const Self) Self {
            const a = self.inner;
            const b = other.inner;

            var inner: [Self.dim][Self.dim]T = Self.zeros().inner;

            for (0..Self.dim) |i| {
                for (0..Self.dim) |j| {
                    for (0..Self.dim) |k| {
                        inner[i][j] += a[i][k] * b[k][j];
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn transpose(self: *const Self) Self {
            var m = self.inner;
            const a, const b = .{ m[0][1], m[1][0] };
            m[0][1], m[1][0] = .{ b, a };

            return Self{ .inner = m };
        }
    };
}

pub fn Mat3(comptime T: type) type {
    return struct {
        inner: [Self.dim][Self.dim]T,

        pub const dim = 3;

        const Self = @This();

        pub fn identity() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = if (i == j) 1 else 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn zeros() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn buildRows(v0: []const T, v1: []const T, v2: []const T) Self {
            var inner = Self.zeros().inner;

            for (0..Self.dim) |j| {
                inner[0][j] = v0[j];
                inner[1][j] = v1[j];
                inner[2][j] = v2[j];
            }

            return Self{ .inner = inner };
        }

        pub fn buildColumns(c0: []const T, c1: []const T, c2: []const T) Self {
            var inner = Self.zeros().inner;

            for (0..Self.dim) |i| {
                inner[i][0] = c0[i];
                inner[i][1] = c1[i];
                inner[i][2] = c2[i];
            }

            return Self{ .inner = inner };
        }

        pub fn mulVec(self: *const Self, vector: vec.Vec3(T)) vec.Vec3(T) {
            const m = self.inner;
            const v = vector;

            return vec.Vec3(T).build(
                m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z,
                m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z,
                m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z,
            );
        }

        pub fn mulMat(self: *const Self, other: *const Self) Self {
            const a = self.inner;
            const b = other.inner;

            var inner: [Self.dim][Self.dim]T = Self.zeros().inner;

            for (0..Self.dim) |i| {
                for (0..Self.dim) |j| {
                    for (0..Self.dim) |k| {
                        inner[i][j] += a[i][k] * b[k][j];
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn transpose(self: *const Self) Self {
            var m = self.inner;
            const a, const b, const c = .{ m[0][1], m[0][2], m[1][2] };
            const d, const e, const f = .{ m[1][0], m[2][0], m[2][1] };
            m[0][1], m[0][2], m[1][2] = .{ d, e, f };
            m[1][0], m[2][0], m[2][1] = .{ a, b, c };

            return Self{ .inner = m };
        }
    };
}

pub fn Mat4(comptime T: type) type {
    return struct {
        inner: [Self.dim][Self.dim]T,

        pub const dim = 4;

        const Self = @This();

        pub fn identity() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = if (i == j) 1 else 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn zeros() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn mulVec(self: *const Self, vector: vec.Vec4(T)) vec.Vec4(T) {
            const m = self.inner;
            const v = vector;

            return vec.Vec4(T).build(
                m[0][0] * v.x + m[0][1] * v.y + m[0][2] * v.z + m[0][3] * v.w,
                m[1][0] * v.x + m[1][1] * v.y + m[1][2] * v.z + m[1][3] * v.w,
                m[2][0] * v.x + m[2][1] * v.y + m[2][2] * v.z + m[2][3] * v.w,
                m[3][0] * v.x + m[3][1] * v.y + m[3][2] * v.z + m[3][3] * v.w,
            );
        }

        pub fn mulMat(self: *const Self, other: *const Self) Self {
            const a = self.inner;
            const b = other.inner;

            var inner: [Self.dim][Self.dim]T = Self.zeros().inner;

            for (0..Self.dim) |i| {
                for (0..Self.dim) |j| {
                    for (0..Self.dim) |k| {
                        inner[i][j] += a[i][k] * b[k][j];
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn transpose(self: *const Self) Self {
            var inner: [Self.dim][Self.dim]T = undefined;
            for (0..Self.dim) |i| {
                for (0..Self.dim) |j| {
                    inner[i][j] = self.inner[j][i];
                }
            }

            return Self{ .inner = inner };
        }
    };
}

pub fn MatN(comptime T: type, comptime N: usize) type {
    return struct {
        inner: [N][N]T,

        pub const dim = N;

        const Self = @This();

        pub fn identity() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            @setEvalBranchQuota(1_000_000);
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = if (i == j) 1 else 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn zeros() Self {
            comptime var inner: [Self.dim][Self.dim]T = undefined;
            @setEvalBranchQuota(1_000_000);
            comptime {
                for (0..Self.dim) |i| {
                    for (0..Self.dim) |j| {
                        inner[i][j] = 0;
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn mulVec(self: *const Self, vector: vec.VecN(T, Self.dim)) vec.VecN(T, Self.dim) {
            std.debug.assert(Self.dim == vector.dim);

            const m = self.inner;
            const v = vector;
            var result = vec.VecN(T, Self.dim).zeros();

            for (0..Self.dim) |i| {
                var sum: T = 0;
                for (0..Self.dim) |j| {
                    sum += m[i][j] * v[j];
                }
                result.inner[i] = sum;
            }

            return result;
        }

        pub fn mulMat(self: *const Self, other: *const Self) Self {
            const a = self.inner;
            const b = other.inner;

            var inner: [Self.dim][Self.dim]T = Self.zeros().inner;

            for (0..Self.dim) |i| {
                for (0..Self.dim) |j| {
                    for (0..Self.dim) |k| {
                        inner[i][j] += a[i][k] * b[k][j];
                    }
                }
            }

            return Self{ .inner = inner };
        }

        pub fn transpose(self: *const Self) Self {
            var inner: [Self.dim][Self.dim]T = undefined;
            for (0..Self.dim) |i| {
                for (0..Self.dim) |j| {
                    inner[i][j] = self.inner[j][i];
                }
            }

            return Self{ .inner = inner };
        }
    };
}

test "matrix vec mul testing" {
    const matrix = Mat4(f32).identity();
    const vector = vec.Vec4(f32).build(10, 10, 99, 123);
    const prod = matrix.mulVec(vector);
    std.debug.print("product: {any}\nmatrix: {any}\nvec: {any}\n", .{ prod, matrix, vector });
    try std.testing.expect(std.meta.eql(vector, prod));
}

test "matrix matrix mul testing" {
    const matrix1 = Mat4(f32).identity();
    const matrix2 = Mat4(f32).identity();
    const prod = matrix1.mulMat(&matrix2);
    std.debug.print("product: {any}\n", .{prod});
    try std.testing.expect(std.meta.eql(matrix1, prod));

    const matrixn1 = MatN(f32, 100).identity();
    const matrixn2 = MatN(f32, 100).identity();
    const prod1 = matrixn1.mulMat(&matrixn2);
    try std.testing.expect(std.meta.eql(matrixn1, prod1));
}
