proc threadFunc() {.thread.} =
  stdout.write "b"
  stdout.write "c"

var thr: Thread[void]
stdout.write "a"
createThread(thr, threadFunc)
joinThreads(thr)
stdout.write "d" 