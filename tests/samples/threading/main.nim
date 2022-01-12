proc threadFunc() {.thread.} =
  echo "a"
  echo "b"

var thr: Thread[void]
createThread(thr, threadFunc)
joinThreads(thr)
