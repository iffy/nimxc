# Package

version       = "0.1.0"
author        = "Matt Haggard"
description   = "A helper to get cross-compiling working"
license       = "MIT"
srcDir        = "src"
bin           = @["nimxc"]


# Dependencies

requires "nim >= 1.4.0"
requires "argparse >= 2.0.1"
