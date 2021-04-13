id: iptdty93ql2jiji2z2rx4a19tqyqp3t1v38lmlf2kszhzdvo
name: sevendrl
main: src/main.zig
dev_dependencies:
  - src: git https://github.com/leroycep/seizer.git
    version: branch-controllers
  - src: git https://github.com/leroycep/zigmath.git
  - src: git https://github.com/leroycep/zigimg.git
    version: branch-wasm
    name: zigimg
    main: zigimg.zig
  - src: git https://github.com/leroycep/zig-ecs.git
    name: ecs
    main: src/ecs.zig

