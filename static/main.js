import getPlatformEnv from "./platform.js";

const canvas_element = document.getElementById("game-canvas");
var globalInstance;
const getMemory = () => globalInstance.exports.memory;
const getMemU32 = (ptr) => new Uint32Array(getMemory().buffer, ptr, 1)[0];

let utf8encoder = new TextEncoder();
let utf8decoder = new TextDecoder();

var js_promises = {};
var open_js_promise_ids = [];

class NotFoundError extends Error {
    constructor() {
        super("File not found");
        this.name = "NotFoundError";
    }
}
class OutOfMemoryError extends Error {
    constructor() {
        super("Out of memory");
        this.name = "OutOfMemoryError";
    }
}

let env = {
    ...getPlatformEnv(canvas_element, () => globalInstance),
};

function getErrorName(errno) {
    const ptr = globalInstance.exports.error_name_ptr(errno);
    const len = globalInstance.exports.error_name_len(errno);
    return utf8decoder.decode(new Uint8Array(getMemory().buffer, ptr, len));
}

fetch("2021-7drl-web.wasm")
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, { env }))
    .then((results) => results.instance)
    .then((instance) => {
        globalInstance = instance;
        instance.exports._start();
    });
