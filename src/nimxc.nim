import std/httpclient
import std/os
import std/osproc
import std/sequtils
import std/strformat
import std/strutils
import std/tables

import zippy/ziparchives

type
  Pair* = string
  Target = tuple
    os: string
    cpu: string
    extra: string
  InstallProc = proc(dir: string): void {.closure.}
  ArgsProc = proc(dir: string): seq[string] {.closure.}
  Bundle = tuple
    install: InstallProc
    args: ArgsProc

proc `$`(t: Target): string =
  result = &"{t.os}-{t.cpu}"
  if t.extra != "":
    result.add "-" & t.extra

proc zigfmt(t: Target): string =
  result = &"{t.cpu}-{t.os}"
  if t.extra != "":
    result.add "-" & t.extra

var host_systems* = newTable[Pair, TableRef[Pair, Bundle]]()
const THIS_HOST*: Pair = &"{hostOS}-{hostCPU}"

proc targetExeExt*(target: Pair): string =
  if "windows" in target:
    return "exe"
  else:
    return ""

proc getDir*(url: string): string =
  let arname = url.extractFilename
  if arname.endsWith(".zip"):
    return arname.changeFileExt("")
  elif arname.endsWith(".tar.xz"):
    return arname.changeFileExt("").changeFileExt("")
  return arname.changeFileExt("")

#======================================================================
# Target definitions
#======================================================================

proc install_zig(src_url: string, toolchains: string) =
  let dlcache = toolchains / "download"
  let dlfilename = dlcache / src_url.extractFilename()
  let dstsubdir = if dlfilename.endsWith(".zip"):
      toolchains / dlfilename.extractFilename.changeFileExt("")
    else:
      toolchains / dlfilename.extractFilename.changeFileExt("").changeFileExt("")
  let zigpath = absolutePath(dstsubdir / "zig").changeFileExt(ExeExt)
  let zigcc = absolutePath(dstsubdir / "zigcc").changeFileExt(ExeExt)
  
  if not dstsubdir.dirExists:
    if not dlfilename.fileExists:
      # download it
      createDir(dlcache)
      echo &"Downloading {src_url} to {dlfilename} ..."
      let client = newHttpClient()
      defer: client.close()
      client.downloadFile(src_url, dlfilename)
    # extract it
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
  
  # make zigcc
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
    let output = execProcess(findExe"nim", args = ["c", "-d:release", "-o:" & zigcc, zigcc.changeFileExt("nim")], options={poStdErrToStdOut})
    if not zigcc.fileExists:
      echo output
      echo readFile(zigcc.changeFileExt("nim"))
      raise ValueError.newException("Failed to compile zigcc")
    echo "Created zigcc at ", zigcc

proc install_sdk(src_url: string, toolchains: string) =
  let dlcache = toolchains / "download"
  let dlfilename = dlcache / src_url.extractFilename()
  let dstsubdir = toolchains / dlfilename.extractFilename.changeFileExt("").changeFileExt("")

  if not dstsubdir.dirExists:
    if not dlfilename.fileExists:
      # download it
      createDir(dlcache)
      echo &"Downloading {src_url} to {dlfilename} ..."
      let client = newHttpClient()
      defer: client.close()
      client.downloadFile(src_url, dlfilename)
    # extract it
    echo &"Extracting {dlfilename} to {dstsubdir}"
    var p = startProcess(findExe"tar",
      args=["--force-local", "-x", "-C", toolchains, "-f", dlfilename],
      options={poStdErrToStdOut, poParentStreams})
    doAssert p.waitForExit() == 0

const zigcc_name = "zigcc".changeFileExt(ExeExt)

# See https://nim-lang.org/docs/system.html#hostCPU for possible CPU arch values

const nimArchToZigArch = {
  "arm64": "aarch64",
  "amd64": "x86_64",
  "i386": "i386",
}.toTable()

const nimOStoZigOS = {
  "macosx": "macos",
}.toTable()

const zigVersion = "0.10.1"

const sdkurl = "https://ivan.vandot.rs/macosx-sdk.14.2.tar.xz"

const zigurls = {
  "macosx-amd64": &"https://ziglang.org/download/{zigVersion}/zig-macos-x86_64-{zigVersion}.tar.xz",
  "macosx-arm64": &"https://ziglang.org/download/{zigVersion}/zig-macos-aarch64-{zigVersion}.tar.xz",
  "linux-amd64": &"https://ziglang.org/download/{zigVersion}/zig-linux-x86_64-{zigVersion}.tar.xz",
  "linux-i386": &"https://ziglang.org/download/{zigVersion}/zig-linux-i386-{zigVersion}.tar.xz",
  "linux-arm64": &"https://ziglang.org/download/{zigVersion}/zig-linux-aarch64-{zigVersion}.tar.xz",
  "linux-riscv64": &"https://ziglang.org/download/{zigVersion}/zig-linux-riscv64-{zigVersion}.tar.xz",
  "windows-amd64": &"https://ziglang.org/download/{zigVersion}/zig-windows-x86_64-{zigVersion}.zip",
  "windows-i386": &"https://ziglang.org/download/{zigVersion}/zig-windows-i386-{zigVersion}.zip",
  "windows-arm64": &"https://ziglang.org/download/{zigVersion}/zig-windows-aarch64-{zigVersion}.zip",
}.toTable()

proc mkArgs(zig_root: string, sdk_root: string, target: Target): seq[string] =
  ## Return the compiler args for the given target
  var zig_target = (
    nimOStoZigOS.getOrDefault(target.os, target.os),
    nimArchToZigArch.getOrDefault(target.cpu, target.cpu),
    target.extra,
  )
  result = @[
    "--cc:clang",
    "--cpu:" & target.cpu,
    "--os:" & target.os,
    &"-d:nimxc_host_os_" & hostOS,
    $"-d:nimxc_host_cpu_" & hostCPU,
    &"--{target.cpu}.{target.os}.clang.path:{zig_root}",
    &"--{target.cpu}.{target.os}.clang.exe:{zigcc_name}",
    &"--{target.cpu}.{target.os}.clang.linkerexe:{zigcc_name}",
    &"--passC:-target {zig_target.zigfmt} -fno-sanitize=undefined",
    &"--passL:-target {zig_target.zigfmt} -fno-sanitize=undefined",
  ]
  if "macosx" in $target:
    result.add &"--passC:-I{sdk_root}/usr/include -fno-sanitize=undefined"
    result.add &"--passL:-F{sdk_root}/System/Library/Frameworks -fno-sanitize=undefined"
    result.add &"--passL:-L{sdk_root}/usr/lib -fno-sanitize=undefined"

#----------------------------------------------------------------------
const targets : seq[Target] = @[
  ("macosx", "amd64", ""),
  ("macosx", "arm64", ""),
  ("linux", "i386", ""),
  ("linux", "amd64", ""),
  ("linux", "amd64", "gnu.2.27"),
  ("linux", "amd64", "gnu.2.28"),
  ("linux", "amd64", "gnu.2.31"),
  ("linux", "arm64", ""),
  ("linux", "riscv64", ""),
  ("windows", "i386", ""),
  ("windows", "amd64", ""),
  ("windows", "arm64", ""),
]

for host, url in zigurls.pairs:
  closureScope:
    let this_host = host
    let this_url = url
    if not host_systems.hasKey(this_host):
      host_systems[this_host] = newTable[Pair, Bundle]()
    let dirname = getDir(url)
    let sdkdirname = getDir(sdkurl)
    for target in targets:
      let targ: Target = (target.os, target.cpu, target.extra) # this is for closure purposes
      closureScope:
        let this_targ: Target = (targ.os, targ.cpu, targ.extra)
        proc install(toolchains: string) {.closure.} =
          install_zig(this_url, toolchains)
          if "macosx" in $this_targ:
            install_sdk(sdkurl, toolchains)
        proc args(toolchains: string): seq[string] {.closure.} =
          let zig_root = absolutePath(toolchains / dirname)
          let sdk_root = absolutePath(toolchains / sdkdirname)
          mkArgs(zig_root, sdk_root, this_targ)
        let install_proc: InstallProc = install
        let args_proc: ArgsProc = args
        host_systems[host][$this_targ] = (install_proc, args_proc)

# add nop targets for the host itself
for key in host_systems.keys:
  block:
    proc install(toolchains: string) = discard
    proc args(toolchains: string): seq[string] = discard
    let install_proc: InstallProc = install
    let args_proc: ArgsProc = args
    host_systems[key][key] = (install_proc, args_proc)

#======================================================================
proc targets_for(host: Pair): seq[Pair] =
  if host_systems.hasKey(host):
    return toSeq(host_systems[host].keys)

proc get_bundle(host: Pair, target: Pair): Bundle =
  if not host_systems.hasKey(host):
    raise ValueError.newException("No such host: " & host)
  if not host_systems[host].hasKey(target):
    raise ValueError.newException(&"Target {target} unsupported on {host}. Acceptable targets: " & targets_for(host).join(", "))
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

const DEFAULT_TOOLCHAIN_DIR* = expandTilde("~/.nimxc")

proc exec_nim_c*(host: Pair, target: Pair, toolchains: string, args: openArray[string]): int =
  ## Execute 'nim c' but cross-compile for the given `target`
  var full_args = @["c"]
  full_args.add(host.compile_args(target, toolchains))
  full_args.add(args)
  echo "nim ", full_args.join(" ")
  var p = startProcess(findExe"nim", args = full_args, options = {poParentStreams})
  defer: p.close()
  p.waitForExit()

proc all_host_archs*(): seq[string] =
  ## Return all possible architectures/targets defining this host system
  when defined(linux):
    result.add THIS_HOST
    result.add THIS_HOST & "-musl"
    let ldd = findExe"ldd"
    if ldd != "":
      let res = execCmdEx("ldd --version")
      # ldd (Ubuntu GLIBC 2.27-3ubuntu1) 2.27
      if res.exitCode == 0:
        let version = res.output.splitLines()[0].split(" ")[^1]
        result.add THIS_HOST & "-gnu." & version
  else:
    return @[THIS_HOST]

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
          for targ in targets_for(THIS_HOST):
            echo &"--target {targ}"
    command("this"):
      help("Return this machine's architecture and os")
      flag("-a", "--all", help="Show all possible architectures/ABIs supported by this host machine")
      run:
        if opts.all:
          for line in all_host_archs():
            echo line
        else:
          echo $THIS_HOST
    command("c"):
      help("Compile a nim file for the given target")
      option("-t", "--target", help="Target system.")
      flag("--no-auto-install", help="If given, don't attempt to install the toolchain if it's missing")
      option("-d", "--directory", help="Directory where toolchains were installed", default=some(DEFAULT_TOOLCHAIN_DIR))
      arg("args", nargs = -1, help="Options to be passed directly to 'nim c'")
      run:
        if not opts.no_auto_install:
          THIS_HOST.install_toolchain(opts.target, opts.directory)
        quit(THIS_HOST.exec_nim_c(opts.target, opts.directory, opts.args))
  p.run()
