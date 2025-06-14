const lib = @import("root.zig");

pub fn main() !void {
    var general_allocator = lib.std.heap.DebugAllocator(.{}).init;
    defer lib.std.debug.print("allocator health status: {}", .{general_allocator.deinit()});

    var app = lib.app.Application{
        .inputs = lib.sim.Inputs.init(),
        .simulation = try lib.sim.Simulation.init(general_allocator.allocator()),
        .renderer = try lib.ren.Renderer.init(general_allocator.allocator()),
    };
    defer app.deinit();

    try app.run();
}
