import std/os
import std/osproc
import std/sequtils
import std/strutils
import std/tables
import std/unittest

import nimxc

var toskip = [
  "ssl_from_windows-amd64_to_linux-amd64",
  "ssl_from_macosx-amd64_to_linux-amd64",
  "sqlite_from_windows-amd64_to_linux-amd64-gnu.2.27",
  "sqlite_from_macosx-amd64_to_linux-amd64-gnu.2.27"
  # "regex_from_windows-amd64_to_linux-amd64",
  # "regex_from_macosx-amd64_to_linux-amd64",
]

var samples: seq[string]
for item in (currentSourcePath.parentDir / "samples").walkDir:
  if item.kind == pcDir:
    samples.add(item.path)

let toolchains_root = absolutePath(currentSourcePath.parentDir.parentDir / "_tests/toolchains")
createDir(toolchains_root)

let testdir_root = absolutePath(currentSourcePath.parentDir.parentDir / "_tests/tests")
removeDir(testdir_root)

proc testdir(name: string): string =
  result = testdir_root / name
  createDir(result)

if host_systems.hasKey(THIS_HOST):
  for target in host_systems[THIS_HOST].keys:
    for sample in samples:
      let testname = sample.extractFilename & "_from_" & THIS_HOST & "_to_" & target
      if testname in toskip:
        continue
      test testname:
        echo "-".repeat(60)
        echo testname
        echo "-".repeat(60)
        let subdir = testdir(testname)
        # install the toolchain
        THIS_HOST.install_toolchain(target, toolchains_root)
        # for x in walkDirRec(toolchains_root):
        #   checkpoint x

        # copy sample in
        copyDir(sample, subdir)
        let src = subdir / "main.nim"
        let dst = src.changeFileExt(target.targetExeExt())
        
        # compile
        var args = @["c", "-o:" & dst]
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
