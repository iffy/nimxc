`nimxc` is a command-line utility that makes it really easy to cross-compile Nim
programs. This is ALPHA quality software!

## Installation

```
nimble install https://github.com/iffy/nimxc.git
```

## Usage

```
# Install the cross-compiler toolchain for 64-bit Linux
nimxc install --target linux-x86_64

# Compile `foo.nim` for 64-bit Linux
nimxc c --target linux-x86_64 foo.nim
```

## Platform support

Generated from running `nimxc list --all`:

```
From macosx-amd64
  --target macosx-arm64
  --target linux-x86_64
```

## How it works

It uses [`zig cc`](https://ziglang.org/) as the compiler.
