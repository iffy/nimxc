proc threadFunc() {.thread.} =
  stdout.write "a\n"
  stdout.write "b\n"

var thr: Thread[void]
createThread(thr, threadFunc)
joinThreads(thr)
