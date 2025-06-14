const lib = @import("root.zig");
const vec = lib.vec;
const sim = lib.sim;
const ren = lib.ren;
const win = lib.win;
const std = lib.std;

pub const Application = struct {
    inputs: sim.Inputs,
    simulation: sim.Simulation,
    renderer: ren.Renderer,

    const Self = @This();

    pub fn deinit(self: *Self) void {
        self.renderer.deinit();
    }

    pub fn run(self: *Self) !void {
        while (!self.inputs.key_escape) {
            if (self.renderer.terminal_info.shouldRender(self.simulation.tick)) {
                self.renderer.clear();
                self.renderer.renderSimulation(&self.simulation);
                try self.renderer.commitPass();
            }

            try self.inputs.updateDeltas();
            self.inputs.updateKeys();
            self.inputs.updatePos(1920, 1080);
            try win.setCursorPos(1920, 1080);

            try self.simulation.update(&self.inputs);

            // debugging stuff
            if (@import("builtin").mode == .Debug) {
                const math = std.math;
                const view = &self.simulation.player;

                std.debug.print("\x1b[0Hposition: {}\npitch: {}\nyaw: {}\n", .{
                    view.pos,
                    math.radiansToDegrees(view.pitch),
                    math.radiansToDegrees(view.yaw),
                });
                std.debug.print("front: {any}\nright: {any}\n up: {any}\n", .{
                    view.front,
                    view.right,
                    view.up,
                });

                const info = win.getConsoleScreenBufferInfo() catch null;
                std.debug.print("\x1b[10Hinfo: {any}\n", .{info});
                std.debug.print("buffer size: {}, {}\n", .{ self.renderer.width, self.renderer.height });

                std.debug.print("inputs struct: {any}\n", .{self.inputs});

                const window_size = win.getTerminalDimensionsPixel() catch null;
                std.debug.print("\x1b[33hscreen size info: {any}\n", .{window_size});

                const font_size = win.getFontSize() catch null;
                std.debug.print("\x1b[34hfont size: {any}\n", .{font_size});
            }
        }
    }
};
