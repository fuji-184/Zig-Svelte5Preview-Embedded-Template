const std = @import("std");
const httpz = @import("httpz");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const PORT = 3000;

const ContentType = enum {
    html,
    js,
    css,
    png,
    json,
    other,
};

const Route = struct {
    path: []const u8,
    content: []const u8,
    content_type: ContentType,
};

const routes = [_]Route{
    .{ .path = "/", .content = @embedFile("index.html"), .content_type = .html },
    .{ .path = "/favicon.png", .content = @embedFile("favicon.png"), .content_type = .png },
    .{ .path = "/_app/env.js", .content = @embedFile("env.js"), .content_type = .js },
    .{ .path = "/_app/immutable/assets/0.DGG09u5R.css", .content = @embedFile("0.DGG09u5R.css"), .content_type = .css },
    .{ .path = "/_app/immutable/assets/_layout.DGG09u5R.css", .content = @embedFile("_layout.DGG09u5R.css"), .content_type = .css },
    .{ .path = "/_app/immutable/chunks/disclose-version.BCq_IwhX.js", .content = @embedFile("disclose-version.BCq_IwhX.js"), .content_type = .js },
    .{ .path = "/_app/immutable/chunks/entry.BTwmqzRp.js", .content = @embedFile("entry.BTwmqzRp.js"), .content_type = .js },
    .{ .path = "/_app/immutable/chunks/render.C91Kj6ug.js", .content = @embedFile("render.C91Kj6ug.js"), .content_type = .js },
    .{ .path = "/_app/immutable/chunks/runtime.B1yk9b9W.js", .content = @embedFile("runtime.B1yk9b9W.js"), .content_type = .js },
    .{ .path = "/_app/immutable/entry/app.CRWI3IjR.js", .content = @embedFile("app.CRWI3IjR.js"), .content_type = .js },
    .{ .path = "/_app/immutable/entry/start.gFpOVJfK.js", .content = @embedFile("start.gFpOVJfK.js"), .content_type = .js },
    .{ .path = "/_app/immutable/nodes/0.BbwIq2zZ.js", .content = @embedFile("0.BbwIq2zZ.js"), .content_type = .js },
    .{ .path = "/_app/immutable/nodes/1.Y0jRpyVi.js", .content = @embedFile("1.Y0jRpyVi.js"), .content_type = .js },
    .{ .path = "/_app/immutable/nodes/2.CrzU8KMK.js", .content = @embedFile("2.CrzU8KMK.js"), .content_type = .js },
    .{ .path = "/_app/immutable/nodes/3.BW8GsSiR.js", .content = @embedFile("3.BW8GsSiR.js"), .content_type = .js },
    .{ .path = "/_app/version.json", .content = @embedFile("version.json"), .content_type = .json },
};

fn getContentTypeString(content_type: ContentType) []const u8 {
    return switch (content_type) {
        .html => "text/html",
        .js => "text/javascript",
        .css => "text/css",
        .png => "image/png",
        .json => "application/json",
        .other => "application/octet-stream",
    };
}

fn genericHandler(req: *httpz.Request, res: *httpz.Response) !void {
    const path = req.url.path;
    for (routes) |route| {
        if (std.mem.eql(u8, path, route.path)) {
            res.body = route.content;
            res.header("Content-Type", getContentTypeString(route.content_type));
            return;
        }
    }

    // res.status = .not_found;
    // res.body = "404 Not Found";
    res.body = routes[0].content;
    res.header("Content-Type", getContentTypeString(routes[0].content_type));
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var server = try httpz.Server(void).init(allocator, .{
        .port = PORT,
        .request = .{
            .max_form_count = 20,
        },
    }, {});
    defer server.deinit();
    defer server.stop();

    var router = server.router(.{});
    
    router.get("/json/hello/:name", json, .{});
    router.get("/*", genericHandler, .{});

    std.debug.print("listening http://localhost:{d}/\n", .{PORT});
    try server.listen();
}

fn json(req: *httpz.Request, res: *httpz.Response) !void {
    const name = req.param("name").?;
    try res.json(.{ .hello = name }, .{});
}