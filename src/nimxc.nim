import std/httpclient
import std/os
import std/osproc
import std/strformat
import std/strutils
import std/tables

import zippy/ziparchives

type
  Pair* = string
  Target = tuple
    os: string
    cpu: string
  InstallProc = proc(dir: string): void {.closure.}
  ArgsProc = proc(dir: string): seq[string] {.closure.}
  Bundle = tuple
    install: InstallProc
    args: ArgsProc

proc `$`(t: Target): string = &"{t.os}-{t.cpu}"

var host_systems* = newTable[Pair, TableRef[Pair, Bundle]]()
const THIS_HOST*: Pair = &"{hostOS}-{hostCPU}"

proc targetExeExt*(target: Pair): string =
  if "windows" in target:
    return "exe"
  else:
    return ""

#======================================================================
# Target definitions
#======================================================================

proc install_zig(src_url: string, toolchains: string) =
  # download it
  let dlcache = toolchains / "download"
  createDir(dlcache)
  let dlfilename = dlcache / src_url.extractFilename()
  if not dlfilename.fileExists:
    echo &"Downloading {src_url} to {dlfilename} ..."
    let client = newHttpClient()
    defer: client.close()
    client.downloadFile(src_url, dlfilename)
    # TODO: verify the checksum
  else:
    echo &"Already downloaded {src_url}"
  
  # extract it
  let dstsubdir = if dlfilename.endsWith(".zip"):
      toolchains / dlfilename.extractFilename.changeFileExt("")
    else:
      toolchains / dlfilename.extractFilename.changeFileExt("").changeFileExt("")
  if not dstsubdir.dirExists:
    echo &"Extracting {dlfilename} to {dstsubdir}"
    if dlfilename.endsWith(".zip"):
      let tmpdir = toolchains / "tmp"
      extractAll(dlfilename, tmpdir)
      moveDir(tmpdir / dstsubdir.extractFilename, dstsubdir)
    else:
      var p = startProcess(findExe"tar",
        args=["-x", "-C", toolchains, "-f", dlfilename],
        options={poStdErrToStdOut, poParentStreams})
      doAssert p.waitForExit() == 0
  else:
    echo "Already installed: " & dstsubdir
  
  # make zigcc
  let zigpath = absolutePath(dstsubdir / "zig").changeFileExt(ExeExt)
  echo "Ensuring zigcc is present ..."
  let zigcc = absolutePath(dstsubdir / "zigcc").changeFileExt(ExeExt)
  if not zigcc.fileExists:
    let zigpath_escaped = zigpath.replace("\\", "\\\\")
    writeFile(zigcc.changeFileExt("nim"), dedent(&"""
      import std/osproc
      import std/os
      proc main() =
        var args = @["cc"]
        args.add(commandLineParams())
        var p = startProcess("{zigpath_escaped}", args = args, options = {{poParentStreams}})
        defer: p.close()
        quit(p.waitForExit())
      when isMainModule:
        main()
      """))
    echo execProcess(findExe"nim", args = ["c", "-d:release", "-o:" & zigcc, zigcc.changeFileExt("nim")], options={poStdErrToStdOut})
    if not zigcc.fileExists:
      echo readFile(zigcc.changeFileExt("nim"))
      raise ValueError.newException("Failed to compile zigcc")
    # setFilePermissions(dstsubdir / "zigcc.sh", {fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupWrite, fpGroupExec})
  echo zigcc.extractFilename, " present: " & zigcc

const zigcc_name = "zigcc".changeFileExt(ExeExt)

# See https://nim-lang.org/docs/system.html#hostCPU for possible CPU arch values

const nimArchToZigArch = {
  "arm64": "aarch64",
  "amd64": "x86_64",
  "i386": "x86",
}.toTable()

const nimOStoZigOS = {
  "macosx": "macos",
}.toTable()

const zigurls = {
  "macosx-amd64": "https://ziglang.org/download/0.9.0/zig-macos-x86_64-0.9.0.tar.xz",
  "linux-amd64": "https://ziglang.org/download/0.9.0/zig-linux-x86_64-0.9.0.tar.xz",
  "windows-amd64": "https://ziglang.org/download/0.9.0/zig-windows-x86_64-0.9.0.zip",
}.toTable()

proc mkArgs(zig_root: string, cpu: string, os: string): seq[string] =
  ## Return the compiler args for the given target
  let zig_arch = nimArchToZigArch[cpu]
  let zig_os = nimOStoZigOS.getOrDefault(os, os)
  @[
    "--cc:clang",
    "--cpu:" & cpu,
    "--os:" & os,
    &"--{cpu}.{os}.clang.path:{zig_root}",
    &"--{cpu}.{os}.clang.exe:{zigcc_name}",
    &"--{cpu}.{os}.clang.linkerexe:{zigcc_name}",
    &"--passC:-target {zig_arch}-{zig_os}",
    &"--passL:-target {zig_arch}-{zig_os}",
  ]

#----------------------------------------------------------------------
const targets : seq[Target] = @[
  ("macosx", "amd64"),
  ("macosx", "arm64"),
  ("linux", "i386"),
  ("linux", "amd64"),
  ("windows", "i386"),
  ("windows", "amd64"),   
]

for host, url in zigurls.pairs:
  closureScope:
    let this_host = host
    let this_url = url
    if not host_systems.hasKey(this_host):
      host_systems[this_host] = newTable[Pair, Bundle]()
    let arname = this_url.extractFilename
    let dirname = if arname.endsWith(".zip"):
      arname.changeFileExt("")
    elif arname.endsWith(".tar.xz"):
      arname.changeFileExt("").changeFileExt("")
    else:
      arname.changeFileExt("")
    for target in targets:
      let targ: Target = (target.os, target.cpu)
      closureScope:
        let cpu = targ.cpu
        let os = targ.os
        proc install(toolchains: string) {.closure.} =
          install_zig(this_url, toolchains)
        proc args(toolchains: string): seq[string] {.closure.} =
          let zig_root = absolutePath(toolchains / dirname)
          mkArgs(zig_root, cpu, os)
        let install_proc: InstallProc = install
        let args_proc: ArgsProc = args
        host_systems[host][$targ] = (install_proc, args_proc)

# add nop targets for the host itself
for key in host_systems.keys:
  block:
    proc install(toolchains: string) = discard
    proc args(toolchains: string): seq[string] = discard
    let install_proc: InstallProc = install
    let args_proc: ArgsProc = args
    host_systems[key][key] = (install_proc, args_proc)

#======================================================================

proc get_bundle(host: Pair, target: Pair): Bundle =
  if not host_systems.hasKey(host):
    raise ValueError.newException("No such host: " & host)
  if not host_systems[host].hasKey(target):
    raise ValueError.newException(&"Target {target} unsupported on {host}")
  return host_systems[host][target]

proc compile_args*(host: Pair, target: Pair, dir = ""): seq[string] =
  ## Return the nim compile args to use to compile for the given target
  if host == target:
    return
  get_bundle(host, target).args(dir)

proc install_toolchain*(host: Pair, target: Pair, dir = "") =
  ## Install the toolchain for cross-compiling
  if host == target:
    return
  get_bundle(host, target).install(dir)

const DEFAULT_TOOLCHAIN_DIR = expandTilde("~/.nimxc")

proc exec_nim_c*(host: Pair, target: Pair, toolchains: string, args: openArray[string]): int =
  ## Execute 'nim c' but cross-compile for the given `target`
  var full_args = @["c"]
  full_args.add(host.compile_args(target, toolchains))
  full_args.add(args)
  echo "nim ", full_args.join(" ")
  var p = startProcess(findExe"nim", args = full_args, options = {poParentStreams})
  defer: p.close()
  p.waitForExit()

when isMainModule:
  import std/algorithm
  import argparse
  
  var p = newParser:
    command("install"):
      option("target", help="Target system.")
      option("-d", "--directory", help="Directory in which to install toolchains", default=some(DEFAULT_TOOLCHAIN_DIR))
      help("Install the toolchains to cross compile for --target")
      run:
        THIS_HOST.install_toolchain(opts.target, opts.directory)
    command("args"):
      option("-t", "--target", help="Target system.")
      option("-d", "--directory", help="Directory where toolchains were installed", default=some(DEFAULT_TOOLCHAIN_DIR))
      help("Show nim args needed to cross compile for --target")
      run:
        echo THIS_HOST.compile_args(opts.target, opts.directory).join(" ")
    command("list"):
      help("Show supported targets")
      flag("-a", "--all", help="Show targets supported on architectures other than this host machine")
      run:
        if opts.all:
          for host in toSeq(host_systems.keys).sorted:
            echo &"From {host}"
            for dst in toSeq(host_systems[host].keys).sorted:
              echo &"  --target {dst}"
        else:
          if host_systems.hasKey(THIS_HOST):
            for dst in host_systems[THIS_HOST].keys:
              echo &"--target {dst}"
    command("this"):
      help("Return this machine's architecture and os")
      run:
        echo $THIS_HOST
    command("c"):
      help("Compile a nim file for the given target")
      option("-t", "--target", help="Target system.")
      option("-d", "--directory", help="Directory where toolchains were installed", default=some(DEFAULT_TOOLCHAIN_DIR))
      arg("args", nargs = -1, help="Options to be passed directly to 'nim c'")
      run:
        quit(THIS_HOST.exec_nim_c(opts.target, opts.directory, opts.args))
  p.run()
