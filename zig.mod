id: iptdty93ql2jiji2z2rx4a19tqyqp3t1v38lmlf2kszhzdvo
name: 2021-7drl
main: src/main.zig
dependencies:
- type: git
  path: https://github.com/leroycep/seizer.git
- type: git
  path: https://github.com/leroycep/zigmath.git
- type: git
  path: https://github.com/leroycep/zigimg.git
  version: branch-wasm
  name: zigimg
  main: zigimg.zig
- type: git
  path: https://github.com/leroycep/zig-ecs.git
  name: ecs
  main: src/ecs.zig

