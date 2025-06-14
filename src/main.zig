const lib = @import("root.zig");

pub fn main() !void {
    var general_allocator = lib.std.heap.DebugAllocator(.{}).init;
    defer lib.std.debug.print("allocator health status: {}", .{general_allocator.deinit()});
    const allocator = general_allocator.allocator();

    var app = lib.app.Application{
        .inputs = try lib.sim.Inputs.init(),
        .simulation = try lib.sim.Simulation.init(allocator),
        .renderer = try lib.ren.Renderer.init(allocator),
    };
    defer app.deinit();

    try app.run();
}
