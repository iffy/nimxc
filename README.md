[![tests](https://github.com/iffy/nimxc/actions/workflows/main.yml/badge.svg)](https://github.com/iffy/nimxc/actions/workflows/main.yml)

`nimxc` is a command-line utility that makes it really easy to cross-compile Nim
programs. This is ALPHA quality software!

## Installation

```
nimble install https://github.com/iffy/nimxc.git
```

## Usage

```
# Install the cross-compiler toolchain for 64-bit Linux
nimxc install --target linux-amd64

# Compile `foo.nim` for 64-bit Linux
nimxc c --target linux-amd64 foo.nim

# see more
nimxc --help
```

## Platform support

Generated from running `nimxc list --all`:

```
From linux-amd64
  --target macosx-amd64
  --target macosx-arm64
  --target windows-amd64
From macosx-amd64
  --target linux-amd64
  --target macosx-arm64
From windows-amd64
  --target linux-amd64
```

## How it works

It uses [`zig cc`](https://ziglang.org/) as the compiler.
