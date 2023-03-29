[![tests](https://github.com/iffy/nimxc/actions/workflows/main.yml/badge.svg)](https://github.com/iffy/nimxc/actions/workflows/main.yml)

`nimxc` is a command-line utility that makes it really easy to cross-compile Nim
programs. This is ALPHA quality software!

## Installation

```
nimble install https://github.com/iffy/nimxc.git
```

## Usage

```
# Compile `foo.nim` for 64-bit Linux
nimxc c --target linux-amd64 foo.nim
# or Intel macOS
nimxc c --target macosx-amd64 foo.nim
# or M1 macOS
nimxc c --target macosx-arm64 foo.nim

# see more
nimxc --help
```

## Platform support

The following hosts and targets are supported except for some situations captured in [Issues](https://github.com/iffy/nimxc/issues).
Some dynamic libraries aren't working yet.
Generated from running `nimxc list --all`:

```
From linux-amd64
  --target linux-amd64
  --target linux-amd64-gnu.2.27
  --target linux-amd64-gnu.2.28
  --target linux-amd64-gnu.2.31
  --target linux-i386
  --target linux-arm64
  --target linux-riscv64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
  --target windows-arm64
  --target windows-i386
From linux-i386
  --target linux-amd64
  --target linux-amd64-gnu.2.27
  --target linux-amd64-gnu.2.28
  --target linux-amd64-gnu.2.31
  --target linux-i386
  --target linux-arm64
  --target linux-riscv64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
  --target windows-arm64
  --target windows-i386
From macosx-amd64
  --target linux-amd64
  --target linux-amd64-gnu.2.27
  --target linux-amd64-gnu.2.28
  --target linux-amd64-gnu.2.31
  --target linux-i386
  --target linux-arm64
  --target linux-riscv64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
  --target windows-arm64
  --target windows-i386
From macosx-arm64
  --target linux-amd64
  --target linux-amd64-gnu.2.27
  --target linux-amd64-gnu.2.28
  --target linux-amd64-gnu.2.31
  --target linux-i386
  --target linux-arm64
  --target linux-riscv64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
  --target windows-arm64
  --target windows-i386
From windows-amd64
  --target linux-amd64
  --target linux-amd64-gnu.2.27
  --target linux-amd64-gnu.2.28
  --target linux-amd64-gnu.2.31
  --target linux-i386
  --target linux-arm64
  --target linux-riscv64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
  --target windows-arm64
  --target windows-i386
From windows-arm64
  --target linux-amd64
  --target linux-amd64-gnu.2.27
  --target linux-amd64-gnu.2.28
  --target linux-amd64-gnu.2.31
  --target linux-i386
  --target linux-arm64
  --target linux-riscv64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
  --target windows-arm64
  --target windows-i386
From windows-i386
  --target linux-amd64
  --target linux-amd64-gnu.2.27
  --target linux-amd64-gnu.2.28
  --target linux-amd64-gnu.2.31
  --target linux-i386
  --target linux-arm64
  --target linux-riscv64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
  --target windows-arm64
  --target windows-i386
```

## How it works

It uses [`zig cc`](https://ziglang.org/) as the compiler. Thanks, Zig!
