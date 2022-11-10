const c = @import("c.zig");
const node = @import("node.zig");
const std = @import("std");
const clib = @cImport({
    @cInclude("sys/socket.h");
    @cInclude("errno.h");
    @cInclude("netdb.h");
});
const builtin = @import("builtin");

pub const constants = .{
    .c_import = clib,
    .names = [_][:0]const u8{
        "EADDRINUSE",   "EADDRNOTAVAIL", "EAFNOSUPPORT", "EALREADY",
        "ECONNREFUSED", "EFAULT",        "EHOSTUNREACH", "EINPROGRESS",
        "EISCONN",      "ENETDOWN",      "ENETUNREACH",  "ENOBUFS",
        "ENOTSOCK",     "EOPNOTSUPP",    "EPROTOTYPE",   "ETIMEDOUT",
        "ECONNRESET",   "ELOOP",         "ENAMETOOLONG",
    },
};

pub fn register(env: c.napi_env, exports: c.napi_value) !void {
    try node.registerFunction(env, exports, "socket", socket);
    try node.registerFunction(env, exports, "_bind", bind);
    try node.registerFunction(env, exports, "_connect", connect);
}

fn socket(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    const argv = node.getArgv(env, info, 3) catch return null;
    const family = node.i32FromValue(env, argv[0], "family") catch return null;
    const socktype = node.i32FromValue(env, argv[1], "socktype") catch return null;
    const protocol = node.i32FromValue(env, argv[2], "protocol") catch return null;

    const fd = clib.socket(family, socktype, protocol);
    if (fd == -1) {
        node.throwErrno(env, "error creating socket");
        return null;
    }
    return node.create_i32(env, fd, "fd") catch return null;
}

// int bind(int socket, const struct sockaddr *address, socklen_t address_len);
// bind: (socket: number, sa_len:number, sa_family:number, sa_data:Buffer) => void;

fn bind(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    const argv = node.getArgv(env, info, 4) catch return null;
    const socket_fd = node.i32FromValue(env, argv[0], "socket") catch return null;
    const sa_len = node.i32FromValue(env, argv[1], "sa_len") catch return null;
    const sa_family = node.i32FromValue(env, argv[2], "sa_family") catch return null;

    var sa_data: [*]u8 = undefined;
    var dummy: usize = undefined;
    if (c.napi_get_buffer_info(env, argv[3], @ptrCast([*c]?*anyopaque, &sa_data), &dummy) != c.napi_ok) {
        node.throwErrno(env, "error reading sa_data");
        return null;
    }

    var sockaddr: clib.sockaddr = undefined;
    sockaddr.sa_data = sa_data[0..14].*; // TODO: I'm dubious!  Maybe just for ipv4?
    if (builtin.target.os.tag != .linux) {
        sockaddr.sa_len = @intCast(u8, sa_len);
    }
    sockaddr.sa_family = @intCast(u8, sa_family);

    std.debug.print("calling bind(socket_fd={}, sockaddr={}, sa_length={})\n", .{ socket_fd, sockaddr, @sizeOf(clib.sockaddr) });
    const fd = clib.bind(socket_fd, &sockaddr, @sizeOf(clib.sockaddr));
    if (fd == -1) {
        node.throwErrno(env, "error calling bind");
        return null;
    }
    return null;
}

fn connect(env: c.napi_env, info: c.napi_callback_info) callconv(.C) c.napi_value {
    const argv = node.getArgv(env, info, 4) catch return null;
    const socket_fd = node.i32FromValue(env, argv[0], "socket") catch return null;
    const sa_len = node.i32FromValue(env, argv[1], "sa_len") catch return null;
    const sa_family = node.i32FromValue(env, argv[2], "sa_family") catch return null;

    var sa_data: [*]u8 = undefined;
    var dummy: usize = undefined;
    if (c.napi_get_buffer_info(env, argv[3], @ptrCast([*c]?*anyopaque, &sa_data), &dummy) != c.napi_ok) {
        node.throwErrno(env, "error reading sa_data");
        return null;
    }

    var sockaddr: clib.sockaddr = undefined;
    sockaddr.sa_data = sa_data[0..14].*; // TODO: I'm dubious!  Maybe just for ipv4?
    if (builtin.target.os.tag != .linux) {
        sockaddr.sa_len = @intCast(u8, sa_len);
    }
    sockaddr.sa_family = @intCast(u8, sa_family);

    std.debug.print("calling connect(socket_fd={}, sockaddr={}, sa_length={})\n", .{ socket_fd, sockaddr, @sizeOf(clib.sockaddr) });
    const fd = clib.connect(socket_fd, &sockaddr, @sizeOf(clib.sockaddr));
    if (fd == -1) {
        node.throwErrno(env, "error calling connect");
        return null;
    }
    return null;
}

// fn testit() void {
//     var hints: clib.addrinfo = clib.addrinfo{ .ai_flags = 0, .ai_family = clib.AF_UNSPEC, .ai_socktype = clib.SOCK_STREAM, .ai_protocol = 0, .ai_addrlen = 0, .ai_addr = 0, .ai_canonname = 0, .ai_next = 0 };
//     var res: ?*clib.addrinfo = null;
//     //clib.memset(&hints, 0, @sizeOf(clib.addrinfo));

//     if (clib.getaddrinfo("127.0.0.1", "2000", &hints, &res) != 0) {
//         std.debug.print("Error getting addr info\n", .{});
//     } else {
//         if (res) |res2| {
//             std.debug.print("Got res = {}\n", .{res2.ai_addr.*});
//         }
//     }
// }
