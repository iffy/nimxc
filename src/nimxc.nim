import std/httpclient
import std/os
import std/osproc
import std/strutils
import std/strformat
import std/tables

type
  Pair* = string
  InstallProc = proc(dir: string): void {.closure.}
  ArgsProc = proc(dir: string): seq[string] {.closure.}
  Bundle = tuple
    install: InstallProc
    args: ArgsProc

var host_systems* = newTable[Pair, TableRef[Pair, Bundle]]()
const THIS_HOST*: Pair = &"{hostOS}-{hostCPU}"
var this_host_possible_targets {.compileTime.} : seq[Pair] 

template target(host: Pair, target: Pair, body: untyped): untyped =
  block:
    if not host_systems.hasKey(host):
      host_systems[host] = newTable[Pair, Bundle]()
    body
    let install_proc: InstallProc = install
    let args_proc: ArgsProc = args
    host_systems[host][target] = (install_proc, args_proc)
    static:
      if host == THIS_HOST:
        this_host_possible_targets.add(target)

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
  let dstsubdir = toolchains / dlfilename.extractFilename.changeFileExt("").changeFileExt("")
  if not dstsubdir.dirExists:
    echo &"Extracting {dlfilename} to {dstsubdir}"
    var p = startProcess(findExe"tar",
      args=["-vx", "-C", toolchains, "-f", dlfilename],
      options={poStdErrToStdOut, poParentStreams})
    doAssert p.waitForExit() == 0
  else:
    echo "Already installed: " & dstsubdir
  
  # make zigcc
  writeFile(dstsubdir / "zigcc", """#!/bin/bash
zig cc "${@}"
""")
  setFilePermissions(dstsubdir / "zigcc", {fpUserRead, fpUserWrite, fpUserExec, fpGroupRead, fpGroupWrite, fpGroupExec})
  echo "ensured zigcc is present"

# proc install_clang(src_url: string, toolchains: string) =
#   # download it
#   let dlcache = toolchains / "download"
#   createDir(dlcache)
#   let dlfilename = dlcache / src_url.extractFilename()
#   if not dlfilename.fileExists:
#     echo &"Downloading {src_url} to {dlfilename} ..."
#     let client = newHttpClient()
#     defer: client.close()
#     client.downloadFile(src_url, dlfilename)

#     let sig_url = src_url & ".sig"
#     let sig_filename = dlcache / sig_url.extractFilename()
#     echo &"Downloading {sig_url} to {sig_filename} ..."
#     client.downloadFile(sig_url, sig_filename)
#     # TODO: check the sig
#   else:
#     echo &"Already downloaded {src_url}"
  
#   # extract it
#   let dstsubdir = toolchains / dlfilename.extractFilename.changeFileExt("").changeFileExt("")
#   if not dstsubdir.dirExists:
#     echo &"Extracting {dlfilename} to {dstsubdir}"
#     var p = startProcess(findExe"tar",
#       args=["-vx", "-C", toolchains, "-f", dlfilename],
#       options={poStdErrToStdOut, poParentStreams})
#     doAssert p.waitForExit() == 0
#   else:
#     echo "Already installed: " & dstsubdir

#----------------------------------------------------------------------
# macosx
#----------------------------------------------------------------------
target "macosx-amd64", "macosx-arm64":
  let subdir = "zig-macos-x86_64-0.9.0"
  proc install(toolchains: string) =
    install_zig("https://ziglang.org/download/0.9.0/zig-macos-x86_64-0.9.0.tar.xz", toolchains)
  proc args(toolchains: string): seq[string] =
    @[
      "--cc:clang",
      "--cpu:arm64",
      "--os:macosx",
      "--arm64.macosx.clang.path:" & absolutePath(toolchains / subdir),
      "--arm64.macosx.clang.exe:zigcc",
      "--arm64.macosx.clang.linkerexe:zigcc",
      "--passC:-target aarch64-macos",
      "--passL:-target aarch64-macos",
    ]

target "macosx-amd64", "linux-x86_64":
  let subdir = "zig-macos-x86_64-0.9.0"
  proc install(toolchains: string) =
    install_zig("https://ziglang.org/download/0.9.0/zig-macos-x86_64-0.9.0.tar.xz", toolchains)
  proc args(toolchains: string): seq[string] =
    @[
      "--cc:clang",
      "--cpu:amd64",
      "--os:linux",
      "--amd64.linux.clang.path:" & absolutePath(toolchains / subdir),
      "--amd64.linux.clang.exe:zigcc",
      "--amd64.linux.clang.linkerexe:zigcc",
      "--passC:-target x86_64-linux",
      "--passL:-target x86_64-linux",
    ]

#======================================================================

proc get_bundle(host: Pair, target: Pair): Bundle =
  if not host_systems.hasKey(host):
    raise ValueError.newException("No such host: " & host)
  if not host_systems[host].hasKey(target):
    raise ValueError.newException(&"Target {target} unsupported on {host}")
  return host_systems[host][target]

proc compile_args*(host: Pair, target: Pair, dir = ""): seq[string] =
  ## Return the nim compile args to use to compile for the given target
  get_bundle(host, target).args(dir)

proc install_toolchain*(host: Pair, target: Pair, dir = "") =
  ## Install the toolchain for cross-compiling
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
  import argparse
  var p = newParser:
    command("install"):
      option("-t", "--target", help="Target system.", choices=this_host_possible_targets)
      option("-d", "--directory", help="Directory in which to install toolchains", default=some(DEFAULT_TOOLCHAIN_DIR))
      help("Install the toolchains to cross compile for --target")
      run:
        THIS_HOST.install_toolchain(opts.target, opts.directory)
    command("args"):
      option("-t", "--target", help="Target system.", choices=this_host_possible_targets)
      option("-d", "--directory", help="Directory where toolchains were installed", default=some(DEFAULT_TOOLCHAIN_DIR))
      help("Show nim args needed to cross compile for --target")
      run:
        echo THIS_HOST.compile_args(opts.target, opts.directory).join(" ")
    command("list"):
      help("Show supported targets")
      flag("-a", "--all", help="Show targets supported on architectures other than this host machine")
      run:
        if opts.all:
          for host,bundles in host_systems.pairs:
            var marker = if THIS_HOST == host: " (this machine)" else: ""
            echo &"From {host}{marker}"
            for dst in bundles.keys:
              echo &"  --target {dst}"
        else:
          if host_systems.hasKey(THIS_HOST):
            for dst in host_systems[THIS_HOST].keys:
              echo &"--target {dst}"
    command("c"):
      help("Compile a nim file for the given target")
      option("-t", "--target", help="Target system.", choices=this_host_possible_targets)
      option("-d", "--directory", help="Directory where toolchains were installed", default=some(DEFAULT_TOOLCHAIN_DIR))
      arg("args", nargs = -1, help="Options to be passed directly to 'nim c'")
      run:
        quit(THIS_HOST.exec_nim_c(opts.target, opts.directory, opts.args))
  p.run()
