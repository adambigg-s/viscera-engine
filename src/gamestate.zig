const lib = @import("root.zig");
const std = lib.std;
const vec = lib.vec;
const win = lib.win;
const ren = lib.ren;
const mat = lib.mat;

pub const Simulation = struct {
    player: Player,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !Self {
        _ = .{allocator};

        const simulation = Simulation{
            .player = Player.new(),
        };

        return simulation;
    }

    pub fn update(self: *Self, inputs: *Inputs) !void {
        self.player.update(inputs);
    }
};

pub const Player = struct {
    pos: vec.Vec3(f32),
    front: vec.Vec3(f32),
    right: vec.Vec3(f32),
    up: vec.Vec3(f32),
    world_up: vec.Vec3(f32),

    pitch: f32,
    yaw: f32,

    vertical_fov: f32,
    near_plane: f32,
    far_plane: f32,

    look_sensitivity: f32,
    yaw_modifier: f32,
    pitch_modifier: f32,
    move_speed: f32,

    const Self = @This();
    const Mat4 = mat.Mat4(f32);

    const math = lib.std.math;

    pub fn new() Self {
        var output = Player{
            .pos = vec.Vec3(f32).build(0, 0, 5),
            .front = vec.Vec3(f32).build(0, 0, -1),
            .right = vec.Vec3(f32).build(1, 0, 0),
            .up = vec.Vec3(f32).build(0, 1, 0),
            .world_up = vec.Vec3(f32).build(0, 1, 0),

            .pitch = 0,
            .yaw = math.degreesToRadians(90),

            .vertical_fov = math.degreesToRadians(45),
            .near_plane = 0.01,
            .far_plane = 100,

            .look_sensitivity = 1.2,
            .yaw_modifier = 0.02,
            .pitch_modifier = 0.02,
            .move_speed = 0.02,
        };
        output.updateVectors();

        return output;
    }

    pub fn getViewMatrix(self: *const Self) Mat4 {
        // https://medium.com/@carmencincotti/lets-look-at-magic-lookat-matrices-c77e53ebdf78
        // basically use this ^^ but with row-major matrices
        var m = Mat4.identity().inner;

        m[0][0], m[0][1], m[0][2], m[0][3] = .{
            self.right.x,
            self.right.y,
            self.right.z,
            -self.right.innerProduct(self.pos),
        };
        m[1][0], m[1][1], m[1][2], m[1][3] = .{
            self.up.x,
            self.up.y,
            self.up.z,
            -self.up.innerProduct(self.pos),
        };
        m[2][0], m[2][1], m[2][2], m[2][3] = .{
            -self.front.x,
            -self.front.y,
            -self.front.z,
            self.front.innerProduct(self.pos),
        };

        return Mat4{ .inner = m };
    }

    pub fn getProjectionMatrix(self: *const Self, aspect_ratio: f32) Mat4 {
        // https://www.scratchapixel.com/lessons/3d-basic-rendering/perspective-and-orthographic-projection-matrix/orthographic-projection-matrix.html
        var m = Mat4.identity().inner;

        const inv_half_fov, const inv_near_far = .{
            1 / @tan(self.vertical_fov / 2),
            1 / (self.near_plane - self.far_plane),
        };

        m[0][0], m[1][1], m[2][2], m[3][3] = .{
            inv_half_fov / aspect_ratio,
            inv_half_fov,
            (self.far_plane + self.near_plane) * inv_near_far,
            0,
        };
        m[2][3], m[3][2] = .{
            (2 * self.far_plane * self.near_plane) * inv_near_far,
            -1,
        };

        return Mat4{ .inner = m };
    }

    pub fn update(self: *Self, inputs: *Inputs) void {
        self.updateTranslation(inputs);
        self.updateRotation(inputs);
        self.updateVectors();
    }

    fn updateTranslation(self: *Self, inputs: *Inputs) void {
        if (inputs.key_w) {
            self.pos = self.pos.add(self.front.mul(self.move_speed));
        }
        if (inputs.key_s) {
            self.pos = self.pos.sub(self.front.mul(self.move_speed));
        }
        if (inputs.key_a) {
            self.pos = self.pos.sub(self.right.mul(self.move_speed));
        }
        if (inputs.key_d) {
            self.pos = self.pos.add(self.right.mul(self.move_speed));
        }
        if (inputs.key_r) {
            self.pos = self.pos.add(self.up.mul(self.move_speed));
        }
        if (inputs.key_f) {
            self.pos = self.pos.sub(self.up.mul(self.move_speed));
        }
    }

    fn updateRotation(self: *Self, inputs: *Inputs) void {
        const mouse_dx: f32, const mouse_dy: f32 = .{
            @floatFromInt(inputs.mouse_delta.x),
            @floatFromInt(inputs.mouse_delta.y),
        };
        const yaw_delta, const pitch_delta = .{
            mouse_dx * self.look_sensitivity * self.yaw_modifier,
            mouse_dy * self.look_sensitivity * self.pitch_modifier,
        };

        self.yaw -= math.degreesToRadians(yaw_delta);
        self.pitch -= math.degreesToRadians(pitch_delta);
        self.pitch = math.clamp(
            self.pitch,
            math.degreesToRadians(-89),
            math.degreesToRadians(89),
        );
    }

    fn updateVectors(self: *Self) void {
        self.front = vec.Vec3(f32).build(
            math.cos(self.pitch) * math.cos(self.yaw),
            math.sin(self.pitch),
            math.cos(self.pitch) * -math.sin(self.yaw),
        );
        self.front = self.front.normalize();

        self.right = self.front.crossProduct(self.world_up);
        self.right = self.right.normalize();

        self.up = self.right.crossProduct(self.front);
        self.up = self.up.normalize();
    }
};

pub const Inputs = struct {
    key_w: bool = false,
    key_a: bool = false,
    key_s: bool = false,
    key_d: bool = false,
    key_r: bool = false,
    key_f: bool = false,
    key_escape: bool = false,
    mouse_click: bool = false,
    mouse_delta: vec.Vec2(i32),
    mouse_pos: vec.Vec2(i32),

    const Self = @This();

    pub fn init() !Self {
        const output = Inputs{
            .mouse_delta = vec.Vec2(i32).zeros(),
            .mouse_pos = vec.Vec2(i32).build(1920, 1080),
        };
        _ = win.getKeyState(win.vk_w);
        _ = win.getKeyState(win.vk_a);
        _ = win.getKeyState(win.vk_s);
        _ = win.getKeyState(win.vk_d);
        _ = win.getKeyState(win.vk_r);
        _ = win.getKeyState(win.vk_f);
        _ = win.getKeyState(win.vk_escape);
        _ = win.getKeyState(win.vk_mouse_lbutton);

        return output;
    }

    pub fn updateKeys(self: *Self) void {
        self.key_w = win.getKeyState(win.vk_w);
        self.key_a = win.getKeyState(win.vk_a);
        self.key_s = win.getKeyState(win.vk_s);
        self.key_d = win.getKeyState(win.vk_d);
        self.key_r = win.getKeyState(win.vk_r);
        self.key_f = win.getKeyState(win.vk_f);
        self.key_escape = win.getKeyState(win.vk_escape);
        self.mouse_click = win.getKeyState(win.vk_mouse_lbutton);
    }

    pub fn updateDeltas(self: *Self) !void {
        const x, const y = try win.getCursorPosition();
        self.mouse_delta = vec.Vec2(i32).build(x, y).sub(self.mouse_pos);
    }

    pub fn updatePos(self: *Self, x: i32, y: i32) void {
        self.mouse_pos.x = x;
        self.mouse_pos.y = y;
    }
};
