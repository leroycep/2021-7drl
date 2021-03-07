const std = @import("std");
const gl = @import("./gl_es_3v0.zig");
const zigimg = @import("zigimg");

/// Custom functions to make loading easier
pub fn shaderSource(shader: gl.GLuint, source: []const u8) void {
    gl.shaderSource(shader, 1, &source.ptr, &@intCast(c_int, source.len));
}

pub fn compileShader(allocator: *std.mem.Allocator, vertex_source: [:0]const u8, fragment_source: [:0]const u8) !gl.GLuint {
    var vertex_shader = try compilerShaderPart(allocator, gl.VERTEX_SHADER, vertex_source);
    defer gl.deleteShader(vertex_shader);

    var fragment_shader = try compilerShaderPart(allocator, gl.FRAGMENT_SHADER, fragment_source);
    defer gl.deleteShader(fragment_shader);

    const program = gl.createProgram();
    if (program == 0)
        return error.OpenGlFailure;
    errdefer gl.deleteProgram(program);

    gl.attachShader(program, vertex_shader);
    defer gl.detachShader(program, vertex_shader);

    gl.attachShader(program, fragment_shader);
    defer gl.detachShader(program, fragment_shader);

    gl.linkProgram(program);

    var link_status: gl.GLint = undefined;
    gl.getProgramiv(program, gl.LINK_STATUS, &link_status);

    if (link_status != gl.TRUE) {
        var info_log_length: gl.GLint = undefined;
        gl.getProgramiv(program, gl.INFO_LOG_LENGTH, &info_log_length);

        const info_log = try allocator.alloc(u8, @intCast(usize, info_log_length));
        defer allocator.free(info_log);

        gl.getProgramInfoLog(program, @intCast(c_int, info_log.len), null, info_log.ptr);

        std.log.info("failed to compile shader:\n{}", .{info_log});

        return error.InvalidShader;
    }

    return program;
}

pub fn compilerShaderPart(allocator: *std.mem.Allocator, shader_type: gl.GLenum, source: [:0]const u8) !gl.GLuint {
    var shader = gl.createShader(shader_type);
    if (shader == 0)
        return error.OpenGlFailure;
    errdefer gl.deleteShader(shader);

    var sources = [_][*c]const u8{source.ptr};
    var lengths = [_]gl.GLint{@intCast(gl.GLint, source.len)};

    gl.shaderSource(shader, 1, &sources, &lengths);

    gl.compileShader(shader);

    var compile_status: gl.GLint = undefined;
    gl.getShaderiv(shader, gl.COMPILE_STATUS, &compile_status);

    if (compile_status != gl.TRUE) {
        var info_log_length: gl.GLint = undefined;
        gl.getShaderiv(shader, gl.INFO_LOG_LENGTH, &info_log_length);

        const info_log = try allocator.alloc(u8, @intCast(usize, info_log_length));
        defer allocator.free(info_log);

        gl.getShaderInfoLog(shader, @intCast(c_int, info_log.len), null, info_log.ptr);

        std.log.info("failed to compile shader:\n{}", .{info_log});

        return error.InvalidShader;
    }

    return shader;
}

pub fn loadTexture(alloc: *std.mem.Allocator, filePath: []const u8) !gl.GLuint {
    const cwd = std.fs.cwd();
    const image_contents = try cwd.readFileAlloc(alloc, filePath, 500000);
    defer alloc.free(image_contents);

    const load_res = try zigimg.Image.fromMemory(alloc, image_contents);
    defer load_res.deinit();
    if (load_res.pixels == null) return error.ImageLoadFailed;

    var pixelData = try alloc.alloc(u8, load_res.width * load_res.height * 4);
    defer alloc.free(pixelData);

    // TODO: skip converting to RGBA and let OpenGL handle it by telling it what format it is in
    var pixelsIterator = zigimg.color.ColorStorageIterator.init(&load_res.pixels.?);

    var i: usize = 0;
    while (pixelsIterator.next()) |color| : (i += 1) {
        const integer_color = color.toIntegerColor8();
        pixelData[i * 4 + 0] = integer_color.R;
        pixelData[i * 4 + 1] = integer_color.G;
        pixelData[i * 4 + 2] = integer_color.B;
        pixelData[i * 4 + 3] = integer_color.A;
    }

    var tex: gl.GLuint = 0;
    gl.genTextures(1, &tex);
    if (tex == 0)
        return error.OpenGLFailure;

    gl.bindTexture(gl.TEXTURE_2D, tex);
    const width = @intCast(c_int, load_res.width);
    const height = @intCast(c_int, load_res.height);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGBA, width, height, 0, gl.RGBA, gl.UNSIGNED_BYTE, pixelData.ptr);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.NEAREST);
    gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.NEAREST);

    gl.generateMipmap(gl.TEXTURE_2D);

    return tex;
}
