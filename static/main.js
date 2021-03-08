import getPlatformEnv from "./platform.js";

const canvas_element = document.getElementById("game-canvas");
var globalInstance;

let env = {
    ...getPlatformEnv(canvas_element, () => globalInstance),
};

fetch("2021-7drl-web.wasm")
    .then((response) => response.arrayBuffer())
    .then((bytes) => WebAssembly.instantiate(bytes, { env }))
    .then((results) => results.instance)
    .then((instance) => {
        globalInstance = instance;
        instance.exports._start();
    });
