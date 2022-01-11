import std/os
import std/osproc
import std/sequtils
import std/strutils
import std/tables
import std/unittest

import nimxc

const sample_file = """
echo "Hello, world!"
"""
const sample_output = "Hello, world!\n"

const toolchains_root = "_tests/toolchains"
createDir(toolchains_root)
proc toolchain_dir(target: Pair): string =
  toolchains_root / target

const testdir_root = "_tests/tests"
removeDir(testdir_root)

proc testdir(name: string): string =
  result = testdir_root / name
  createDir(result)

if host_systems.hasKey(THIS_HOST):
  suite "from " & THIS_HOST:
    for target in host_systems[THIS_HOST].keys:
      test "to " & target:
        let subdir = testdir("from_" & THIS_HOST & "_to_" & target)
        # install it
        THIS_HOST.install_toolchain(target, toolchains_root)

        # create sample file
        let src = subdir / "main.nim"
        let dst = src.changeFileExt(ExeExt)
        writeFile(src, sample_file)
        
        # compile
        var args = @["c", "-o:" & dst.extractFilename]
        for arg in THIS_HOST.compile_args(target, toolchains_root):
          args.add(arg)
        args.add(src.extractFilename)
        echo "cd " & subdir
        echo "nim " & args.mapIt("'" & it & "'").join(" ")
        var p = startProcess(command = findExe"nim", workingDir = subdir,
          args = args, options = {poParentStreams, poStdErrToStdOut})
        defer: p.close()
        let rc = p.waitForExit()
        echo "# rc = ", $rc
        doAssert rc == 0
        discard execCmd("file " & dst)
