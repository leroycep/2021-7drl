// Promises with an id, so that it can be passed to WASM
var idpromise_promises = {};
var idpromise_open_ids = [];

function idpromise_call(func, args) {
    let params = args || [];
    return new Promise((resolve, reject) => {
        let id = Object.keys(idpromise_promises).length;
        if (idpromise_open_ids.length > 0) {
            id = idpromise_open_ids.pop();
        }
        idpromise_promises[id] = { resolve, reject };
        func(id, ...params);
    });
}

function idpromise_reject(id, errno) {
    idpromise_promises[id].reject(errno);
    idpromise_open_ids.push(id);
    delete idpromise_promises[id];
}

function idpromise_resolve(id, data) {
    idpromise_promises[id].resolve(data);
    idpromise_open_ids.push(id);
    delete idpromise_promises[id];
}

// Platform ENV
export default function getPlatformEnv(canvas_element, getInstance) {
    const getMemory = () => getInstance().exports.memory;
    const utf8decoder = new TextDecoder();
    const readCharStr = (ptr, len) =>
        utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
    const writeCharStr = (ptr, len, lenRetPtr, text) => {
        const encoder = new TextEncoder();
        const message = encoder.encode(text);
        const zigbytes = new Uint8Array(getMemory().buffer, ptr, len);
        let zigidx = 0;
        for (const b of message) {
            if (zigidx >= len - 1) break;
            zigbytes[zigidx] = b;
            zigidx += 1;
        }
        zigbytes[zigidx] = 0;
        if (lenRetPtr !== 0) {
            new Uint32Array(getMemory().buffer, lenRetPtr, 1)[0] = zigidx;
        }
    };

    const initFinished = (maxDelta, tickDelta) => {
        const instance = getInstance();

        let prevTime = performance.now();
        let tickTime = 0.0;
        let accumulator = 0.0;

        function step(currentTime) {
            let delta = (currentTime - prevTime) / 1000; // Delta in seconds
            if (delta > maxDelta) {
                delta = maxDelta; // Try to avoid spiral of death when lag hits
            }
            prevTime = currentTime;

            accumulator += delta;

            while (accumulator >= tickDelta) {
                instance.exports.update(tickTime, tickDelta);
                accumulator -= tickDelta;
                tickTime += tickDelta;
            }

            // Where the render is between two timesteps.
            // If we are halfway between frames (based on what's in the accumulator)
            // then alpha will be equal to 0.5
            const alpha = accumulator / tickDelta;

            instance.exports.render(alpha);

            if (running) {
                window.requestAnimationFrame(step);
            }
        }
        window.requestAnimationFrame(step);
    };

    const gl = canvas_element.getContext("webgl2", {
        antialias: false,
        preserveDrawingBuffer: true,
    });

    if (!gl) {
        throw new Error("The browser does not support WebGL");
    }

    const glShaders = [];
    const glPrograms = [];
    const glBuffers = [];
    const glVertexArrays = [];
    const glTextures = [];
    const glFramebuffers = [];
    const glUniformLocations = [];

    // Set up errno constants to be filled in when `platform_run` is called
    let ERRNO_OUT_OF_MEMORY = undefined;
    let ERRNO_NOT_FOUND = undefined;
    let ERRNO_UNKNOWN = undefined;

    let platform_log_string = "";
    let running = true;

    return {
        platform_run(maxDelta, tickDelta) {
            const instance = getInstance();

            // Load error numbers from WASM
            const dataview = new DataView(instance.exports.memory.buffer);
            ERRNO_OUT_OF_MEMORY = dataview.getUint32(
                instance.exports.ERRNO_OUT_OF_MEMORY,
                true
            );
            ERRNO_NOT_FOUND = dataview.getUint32(
                instance.exports.ERRNO_NOT_FOUND,
                true
            );
            ERRNO_UNKNOWN = dataview.getUint32(
                instance.exports.ERRNO_UNKNOWN,
                true
            );

            // TODO: call async init function
            idpromise_call(instance.exports.onInit).then((_data) => {
                initFinished(maxDelta, tickDelta);
            });
        },
        platform_quit() {
            running = false;
        },
        platform_log_write: (ptr, len) => {
            platform_log_string += utf8decoder.decode(
                new Uint8Array(getMemory().buffer, ptr, len)
            );
        },
        platform_log_flush: () => {
            console.log(platform_log_string);
            platform_log_string = "";
        },
        platform_reject_promise: idpromise_reject,
        platform_resolve_promise: idpromise_resolve,

        platform_fetch: (ptr, len, cb, ctx, allocator) => {
            const instance = getInstance();

            const filename = utf8decoder.decode(
                new Uint8Array(getMemory().buffer, ptr, len)
            );

            fetch(filename)
                .then((response) => {
                    if (!response.ok) {
                        instance.exports.wasm_fail_fetch(cb, ctx, ERRNO_NOT_FOUND);
                    }
                    return response.arrayBuffer();
                })
                .then((buffer) => new Uint8Array(buffer))
                .then(
                    (bytes) => {
                        const wasm_bytes_ptr = instance.exports.wasm_allocator_alloc(
                            allocator,
                            bytes.byteLength
                        );
                        if (wasm_bytes_ptr == 0) {
                            instance.exports.wasm_fail_fetch(
                                cb,
                                ctx,
                                ERRNO_OUT_OF_MEMORY
                            );
                        }

                        const wasm_bytes = new Uint8Array(
                            instance.exports.memory.buffer,
                            wasm_bytes_ptr,
                            bytes.byteLength
                        );
                        wasm_bytes.set(bytes);

                        instance.exports.wasm_finalize_fetch(
                            cb,
                            ctx,
                            wasm_bytes_ptr,
                            bytes.byteLength
                        );
                    },
                    (err) => instance.exports.wasm_fail_fetch(cb, ctx, ERRNO_UNKNOWN)
                );
        },

        getScreenW() {
            return gl.drawingBufferWidth;
        },
        getScreenH() {
            return gl.drawingBufferHeight;
        },

        // GL stuff
        activeTexture(target) {
            gl.activeTexture(target);
        },
        attachShader(program, shader) {
            gl.attachShader(glPrograms[program], glShaders[shader]);
        },
        bindBuffer(type, buffer_id) {
            gl.bindBuffer(type, glBuffers[buffer_id]);
        },
        bindVertexArray(vertex_array_id) {
            gl.bindVertexArray(glVertexArrays[vertex_array_id]);
        },
        bindFramebuffer(target, framebuffer) {
            gl.bindFramebuffer(target, glFramebuffers[framebuffer]);
        },
        bindTexture(target, texture_id) {
            gl.bindTexture(target, glTextures[texture_id]);
        },
        blendFunc(x, y) {
            gl.blendFunc(x, y);
        },
        bufferData(type, count, data_ptr, draw_type) {
            const bytes = new Uint8Array(getMemory().buffer, data_ptr, count);
            gl.bufferData(type, bytes, draw_type);
        },
        checkFramebufferStatus(target) {
            return gl.checkFramebufferStatus(target);
        },
        clear(mask) {
            gl.clear(mask);
        },
        clearColor(r, g, b, a) {
            gl.clearColor(r, g, b, a);
        },
        compileShader(shader) {
            gl.compileShader(glShaders[shader]);
        },
        getShaderCompileStatus(shader) {
            return gl.getShaderParameter(glShaders[shader], gl.COMPILE_STATUS);
        },
        createBuffer() {
            glBuffers.push(gl.createBuffer());
            return glBuffers.length - 1;
        },
        createFramebuffer() {
            glFramebuffers.push(gl.createFramebuffer());
            return glFramebuffers.length - 1;
        },
        createProgram() {
            glPrograms.push(gl.createProgram());
            return glPrograms.length - 1;
        },
        createShader(shader_type) {
            glShaders.push(gl.createShader(shader_type));
            return glShaders.length - 1;
        },
        createTexture() {
            glTextures.push(gl.createTexture());
            return glTextures.length - 1;
        },
        deleteBuffer(id) {
            gl.deleteBuffer(glBuffers[id]);
            glBuffers[id] = undefined;
        },
        deleteProgram(id) {
            gl.deleteProgram(glPrograms[id]);
            glPrograms[id] = undefined;
        },
        deleteShader(id) {
            gl.deleteShader(glShaders[id]);
            glShaders[id] = undefined;
        },
        deleteTexture(id) {
            gl.deleteTexture(glTextures[id]);
            glTextures[id] = undefined;
        },
        depthFunc(x) {
            gl.depthFunc(x);
        },
        detachShader(program, shader) {
            gl.detachShader(glPrograms[program], glShaders[shader]);
        },
        disable(cap) {
            gl.disable(cap);
        },
        createVertexArray() {
            glVertexArrays.push(gl.createVertexArray());
            return glVertexArrays.length - 1;
        },
        drawArrays(type, offset, count) {
            gl.drawArrays(type, offset, count);
        },
        drawElements(mode, count, type, offset) {
            gl.drawElements(mode, count, type, offset);
        },
        enable(x) {
            gl.enable(x);
        },
        enableVertexAttribArray(x) {
            gl.enableVertexAttribArray(x);
        },
        framebufferTexture2D(target, attachment, textarget, texture, level) {
            gl.framebufferTexture2D(
                target,
                attachment,
                textarget,
                glTextures[texture],
                level
            );
        },
        frontFace(mode) {
            gl.frontFace(mode);
        },
        getAttribLocation_(program_id, name_ptr, name_len) {
            const name = readCharStr(name_ptr, name_len);
            return gl.getAttribLocation(glPrograms[program_id], name);
        },
        getError() {
            return gl.getError();
        },
        getShaderInfoLog(shader, maxLength, length, infoLog) {
            writeCharStr(
                infoLog,
                maxLength,
                length,
                gl.getShaderInfoLog(glShaders[shader])
            );
        },
        getUniformLocation_(program_id, name_ptr, name_len) {
            const name = readCharStr(name_ptr, name_len);
            glUniformLocations.push(
                gl.getUniformLocation(glPrograms[program_id], name)
            );
            return glUniformLocations.length - 1;
        },
        linkProgram(program) {
            gl.linkProgram(glPrograms[program]);
        },
        getProgramLinkStatus(program) {
            return gl.getProgramParameter(glPrograms[program], gl.LINK_STATUS);
        },
        getProgramInfoLog(program, maxLength, length, infoLog) {
            writeCharStr(
                infoLog,
                maxLength,
                length,
                gl.getProgramInfoLog(glPrograms[program])
            );
        },
        pixelStorei(pname, param) {
            gl.pixelStorei(pname, param);
        },
        shaderSource_(shader, string_ptr, string_len) {
            const string = readCharStr(string_ptr, string_len);
            gl.shaderSource(glShaders[shader], string);
        },
        texImage2D(
            target,
            level,
            internal_format,
            width,
            height,
            border,
            format,
            type,
            data_ptr,
            data_len
        ) {
            // FIXME - look at data_ptr, not data_len, to determine NULL?
            const data =
                data_len > 0
                    ? new Uint8Array(getMemory().buffer, data_ptr, data_len)
                    : null;
            gl.texImage2D(
                target,
                level,
                internal_format,
                width,
                height,
                border,
                format,
                type,
                data
            );
        },
        texParameterf(target, pname, param) {
            gl.texParameterf(target, pname, param);
        },
        texParameteri(target, pname, param) {
            gl.texParameteri(target, pname, param);
        },
        uniform1f(location_id, x) {
            gl.uniform1f(glUniformLocations[location_id], x);
        },
        uniform1i(location_id, x) {
            gl.uniform1i(glUniformLocations[location_id], x);
        },
        uniform4f(location_id, x, y, z, w) {
            gl.uniform4f(glUniformLocations[location_id], x, y, z, w);
        },
        uniformMatrix4fv(location_id, data_len, transpose, data_ptr) {
            const floats = new Float32Array(
                getMemory().buffer,
                data_ptr,
                data_len * 16
            );
            gl.uniformMatrix4fv(
                glUniformLocations[location_id],
                transpose,
                floats
            );
        },
        useProgram(program_id) {
            gl.useProgram(glPrograms[program_id]);
        },
        vertexAttribPointer(
            attrib_location,
            size,
            type,
            normalize,
            stride,
            offset
        ) {
            gl.vertexAttribPointer(
                attrib_location,
                size,
                type,
                normalize,
                stride,
                offset
            );
        },
        viewport(x, y, width, height) {
            gl.viewport(x, y, width, height);
        },
    };
}
