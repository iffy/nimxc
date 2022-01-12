{.compile: "./sqlite3/sqlite3.c" .}

when defined(linux):
  {.passC: "-lpthread" .}
  {.passL: "-lpthread" .}

import db_sqlite

when isMainModule:
  let db = open(":memory:", "", "", "")
  for x in db.fastRows(sql"SELECT 123"):
    stdout.write $x
  db.close()
