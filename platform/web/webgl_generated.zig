pub const GLenum = c_uint;
pub const GLboolean = bool;
pub const GLbitfield = c_uint;
pub const GLbyte = i8;
pub const GLshort = i16;
pub const GLint = i32;
pub const GLsizei = i32;
pub const GLintptr = i64;
pub const GLsizeiptr = i64;
pub const GLubyte = u8;
pub const GLushort = u16;
pub const GLuint = u32;
pub const GLfloat = f32;
pub const GLclampf = f32;
pub const VERTEX_SHADER = 35633;
pub const FRAGMENT_SHADER = 35632;
pub const ARRAY_BUFFER = 34962;
pub const ELEMENT_ARRAY_BUFFER = 0x8893;
pub const TRIANGLES = 4;
pub const TRIANGLE_STRIP = 5;
pub const STATIC_DRAW = 35044;
pub const DYNAMIC_DRAW = 0x88E8;
pub const FLOAT = 5126;
pub const DEPTH_TEST = 2929;
pub const LEQUAL = 515;
pub const COLOR_BUFFER_BIT = 16384;
pub const DEPTH_BUFFER_BIT = 256;
pub const STENCIL_BUFFER_BIT = 1024;
pub const TEXTURE_2D = 3553;
pub const RGBA = 6408;
pub const UNSIGNED_BYTE = 5121;
pub const TEXTURE_MAG_FILTER = 10240;
pub const TEXTURE_MIN_FILTER = 10241;
pub const NEAREST = 9728;
pub const TEXTURE0 = 33984;
pub const BLEND = 3042;
pub const SRC_ALPHA = 770;
pub const ONE_MINUS_SRC_ALPHA = 771;
pub const ONE = 1;
pub const NO_ERROR = 0;
pub const FALSE = 0;
pub const TRUE = 1;
pub const UNPACK_ALIGNMENT = 3317;

pub const TEXTURE_WRAP_S = 10242;
pub const CLAMP_TO_EDGE = 33071;
pub const TEXTURE_WRAP_T = 10243;
pub const PACK_ALIGNMENT = 3333;

pub const FRAMEBUFFER = 0x8D40;
pub const RGB = 6407;

pub const COLOR_ATTACHMENT0 = 0x8CE0;
pub const FRAMEBUFFER_COMPLETE = 0x8CD5;
pub const CULL_FACE = 0x0B44;
pub const CCW = 0x0901;
pub const STREAM_DRAW = 0x88E0;

// Data Types
pub const GL_UNSIGNED_SHORT = 0x1403;
pub const GL_UNSIGNED_INT = 0x1405;

pub extern fn activeTexture(target: c_uint) void;
pub extern fn attachShader(program: c_uint, shader: c_uint) void;
pub extern fn bindBuffer(type: c_uint, buffer_id: c_uint) void;
pub extern fn bindVertexArray(vertex_array_id: c_uint) void;
pub extern fn bindFramebuffer(target: c_uint, framebuffer: c_uint) void;
pub extern fn bindTexture(target: c_uint, texture_id: c_uint) void;
pub extern fn blendFunc(x: c_uint, y: c_uint) void;
pub extern fn bufferData(type: c_uint, count: c_long, data_ptr: *const c_void, draw_type: c_uint) void;
pub extern fn checkFramebufferStatus(target: GLenum) GLenum;
pub extern fn clear(mask: GLbitfield) void;
pub extern fn clearColor(r: f32, g: f32, b: f32, a: f32) void;
pub extern fn compileShader(shader: GLuint) void;
pub extern fn getShaderCompileStatus(shader: GLuint) GLboolean;
pub extern fn createBuffer() c_uint;
pub extern fn createFramebuffer() GLuint;
pub extern fn createProgram() GLuint;
pub extern fn createShader(shader_type: GLenum) GLuint;
pub extern fn createTexture() c_uint;
pub extern fn deleteBuffer(id: c_uint) void;
pub extern fn deleteProgram(id: c_uint) void;
pub extern fn deleteShader(id: c_uint) void;
pub extern fn deleteTexture(id: c_uint) void;
pub extern fn depthFunc(x: c_uint) void;
pub extern fn detachShader(program: c_uint, shader: c_uint) void;
pub extern fn disable(cap: GLenum) void;
pub extern fn createVertexArray() c_uint;
pub extern fn drawArrays(type: c_uint, offset: c_uint, count: c_uint) void;
pub extern fn drawElements(mode: GLenum, count: GLsizei, type: GLenum, offset: ?*const c_void) void;
pub extern fn enable(x: c_uint) void;
pub extern fn enableVertexAttribArray(x: c_uint) void;
pub extern fn framebufferTexture2D(target: GLenum, attachment: GLenum, textarget: GLenum, texture: GLuint, level: GLint) void;
pub extern fn frontFace(mode: GLenum) void;
extern fn getAttribLocation_(program_id: c_uint, name_ptr: [*]const u8, name_len: c_uint) c_int;
pub fn getAttribLocation(program_id: c_uint, name: []const u8) c_int {
    return getAttribLocation_(program_id, name.ptr, name.len);
}
pub extern fn getError() c_int;
pub extern fn getShaderInfoLog(shader: GLuint, maxLength: GLsizei, length: ?*GLsizei, infoLog: ?[*]u8) void;
extern fn getUniformLocation_(program_id: c_uint, name_ptr: [*]const u8, name_len: c_uint) c_int;
pub fn getUniformLocation(program_id: c_uint, name: []const u8) c_int {
    return getUniformLocation_(program_id, name.ptr, name.len);
}
pub extern fn linkProgram(program: c_uint) void;
pub extern fn getProgramLinkStatus(program: c_uint) GLboolean;
pub extern fn getProgramInfoLog(program: GLuint, maxLength: GLsizei, length: ?*GLsizei, infoLog: ?[*]u8) void;
pub extern fn pixelStorei(pname: GLenum, param: GLint) void;
extern fn shaderSource_(shader: GLuint, string_ptr: [*]const u8, string_len: c_uint) void;
pub fn shaderSource(shader: GLuint, string: []const u8) void {
    shaderSource_(shader, string.ptr, string.len);
}
pub extern fn texImage2D(target: c_uint, level: c_uint, internal_format: c_uint, width: c_int, height: c_int, border: c_uint, format: c_uint, type: c_uint, data_ptr: ?[*]const u8, data_len: c_uint) void;
pub extern fn texParameterf(target: c_uint, pname: c_uint, param: f32) void;
pub extern fn texParameteri(target: c_uint, pname: c_uint, param: c_uint) void;
pub extern fn uniform1f(location_id: c_int, x: f32) void;
pub extern fn uniform1i(location_id: c_int, x: c_int) void;
pub extern fn uniform4f(location_id: c_int, x: f32, y: f32, z: f32, w: f32) void;
pub extern fn uniformMatrix4fv(location_id: c_int, data_len: c_int, transpose: c_uint, data_ptr: [*]const f32) void;
pub extern fn useProgram(program_id: c_uint) void;
pub extern fn vertexAttribPointer(attrib_location: c_uint, size: c_uint, type: c_uint, normalize: c_uint, stride: c_uint, offset: ?*c_void) void;
pub extern fn viewport(x: c_int, y: c_int, width: c_int, height: c_int) void;
