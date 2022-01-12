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

# import db_sqlite
# export db_sqlite
# export sqlite3

# type
#   QualifiedTable* = tuple
#     schema: string
#     name: string

# proc `$`*(table: QualifiedTable): string {.inline.} =
#   table.schema & "." & table.name

# macro tab*(x: string): untyped =
#   let parts = x.strVal().split(".")
#   doAssert parts.len == 2, "SQLite tables must be fully qualified, not: " & x.strVal()
#   let
#     schema = newLit(parts[0])
#     name = newLit(parts[1])
#   result = quote do:
#     (schema: `schema`, name: `name`)

# type
#   DataType* = enum
#     Null,
#     Int,
#     Float,
#     Text,
#     Blob,
#   Param* = ref ParamObj
#   ParamObj {.acyclic.} = object
#     case kind*: DataType
#     of Int:
#       intval*: BiggestInt
#     of Float:
#       floatval*: BiggestFloat
#     of Text:
#       textval*: string
#     of Blob:
#       blobval*: string
#     of Null:
#       nil
  
#   ColumnNames* = seq[string]
#   ColumnTypes* = seq[DataType]
  
#   AllRow* = object
#     vals*: seq[string]
#     types*: ColumnTypes

#   AllResult* = object
#     rows*: seq[AllRow]
#     colnames*: ColumnNames

#   RunResult* = object
#     lastID*: int64

# proc newParam*(x:string):Param =
#   Param(kind: Text, textval: x)

# proc newParam*(x: int):Param =
#   Param(kind: Int, intval: x)

# proc newParam*(x: int64):Param =
#   Param(kind: Int, intval: x)

# proc newParam*(x:float):Param =
#   Param(kind: Float, floatval: x)

# proc newParam*(x: type(nil)):Param =
#   Param(kind: Null)

# proc newParam*(x: bool):Param =
#   Param(kind: Int, intval: if x: 1 else: 0)

# template P*(x:untyped):untyped = newParam(x)

# proc `$`*(x: Param):string =
#   result = &"<Param {x.kind} "
#   case x.kind
#   of Text:
#     result.add(x.textval)
#   of Int:
#     result.addInt(x.intval)
#   of Float:
#     result.addFloat(x.floatval)
#   of Blob:
#     result.add(x.blobval)
#   of Null:
#     discard
#   result.add(">")


# proc `$`*(x: AllResult): string =
#   result.add "AllResult("
#   result.add "colnames: " & $x.colnames
#   result.add ", rows: " & $x.rows
#   result.add ")"
# proc `$`*(x: ref AllResult): string = $x[]

# proc `==`*(a, b: Param):bool =
#   ## Check two params for equality
#   if a.isNil:
#     if b.isNil: return true
#     return false
#   elif b.isNil or a.kind != b.kind:
#     return false
#   else:
#     case a.kind
#     of Blob:
#       result = a.blobval == b.blobval
#     of Float:
#       result = a.floatval == b.floatval
#     of Int:
#       result = a.intval == b.intval
#     of Null:
#       result = true
#     of Text:
#       result = a.textval == b.textval

# proc `%`*(res:AllResult):JsonNode =
#   result = newJArray()
#   for row in res.rows:
#     var jrow = newJObject()
#     for i,c in res.colnames:
#       case row.types[i]
#       of Blob, Text:
#         jrow[c] = newJString(row.vals[i])
#       of Float:
#         jrow[c] = newJFloat(row.vals[i].parseFloat())
#       of Int:
#         jrow[c] = newJInt(row.vals[i].parseInt())
#       of Null:
#         jrow[c] = newJNull()
#     result.add(jrow)

# proc currentErrMsg*(db:DbConn):string {.inline.} =
#   $sqlite3.errmsg(db) & " (" & $sqlite3.errcode(db) & ")"

# proc raiseErr*(db:DbConn, extra = "") {.noreturn.} =
#   ## Raise the most recent SQLite database error
#   var e: ref DbError
#   new(e)
#   e.msg = db.currentErrMsg()
#   if extra != "":
#     e.msg.add("; " & extra)
#   raise e

# proc prepareAndBindArgs(db:DbConn, query:SqlQuery, params: varargs[Param, `newParam`]):Pstmt =
#   let querystring = query.string
#   if db.prepare_v2(querystring, (querystring.len + 1).cint, result, nil) != SQLITE_OK:
#     db.raiseErr()
#   for i,param in params:
#     case param.kind
#     of Text:
#       let cval = param.textval.cstring
#       if result.bind_text((i+1).cint, cval, cval.len.cint, SQLITE_TRANSIENT) != SQLITE_OK:
#         discard result.finalize()
#         db.raiseErr()
#     of Null:
#       if result.bind_null((i+1).cint) != SQLITE_OK:
#         discard result.finalize()
#         db.raiseErr()
#     of Int:
#       if result.bind_int64((i+1).cint, param.intval) != SQLITE_OK:
#         discard result.finalize()
#         db.raiseErr()
#     of Float:
#       if result.bind_double((i+1).cint, param.floatval) != SQLITE_OK:
#         discard result.finalize()
#         db.raiseErr()
#     of Blob:
#       raise newException(CatchableError, &"Unbindable data type: {param.kind}")

# proc sqliteTypeToDataType(x:int32):DataType =
#   case x
#   of SQLITE_INTEGER:
#     Int
#   of SQLITE_NULL:
#     Null
#   of SQLITE_TEXT:
#     Text
#   of SQLITE_FLOAT:
#     Float
#   of SQLITE_BLOB:
#     Blob
#   else:
#     logging.debug("Unknown SQLITE datatype: " & $x)
#     Null

# proc setColumns(pstmt:Pstmt, numCols: int32, coltypes: var ColumnTypes) =
#   setLen(coltypes, numCols)
#   for i in 0'i32 ..< numCols:
#     coltypes[i] = sqliteTypeToDataType(pstmt.column_type(i))

# iterator queryRows*(db:DbConn, query:SqlQuery, params: varargs[Param, `newParam`], colnames: var ColumnNames, coltypes: var ColumnTypes): Pstmt =
#   var
#     pstmt = db.prepareAndBindArgs(query, params)
#     numCols:int32
#   when LOGSQL:
#     info "(LOGSQL) " & query.string & " / " & $params
#   when TIMING_MODE:
#     let start_time = getTime()
#   let first = step(pstmt)
#   if first == SQLITE_ROW:
#     # get column names
#     numCols = pstmt.column_count()
#     setLen(colnames, numCols)
#     for i in 0'i32 ..< numCols:
#       colnames[i] = $pstmt.column_name(i)
    
#     setColumns(pstmt, numCols, coltypes)
#     yield pstmt

#     # get data
#     while step(pstmt) == SQLITE_ROW:
#       setColumns(pstmt, numCols, coltypes)
#       yield pstmt
#   if finalize(pstmt) != SQLITE_OK:
#     db.raiseErr()
#   when TIMING_MODE:
#     info "(timing.sql) " & $(getTime()-start_time).inMilliseconds() & "ms " & query.string

# proc fetchAll*(db:DbConn, statement:SqlQuery, params: varargs[Param, `newParam`]): ref AllResult =
#   ## Execute a multi-row-returning SQL statement.
#   new(result)
#   var coltypes: ColumnTypes
#   for row in db.queryRows(statement, params, result.colnames, coltypes):
#     var res:AllRow
#     for i,col in coltypes:
#       res.types.add(col)
#       let val = column_text(row, i.int32)
#       res.vals.add(cStringToString(val, val.len.cint))
#     result.rows.add(res)

# proc runQuery*(db:DbConn, query:SqlQuery, params: varargs[Param, `newParam`]): ref RunResult =
#   ## Execute an SQL statement.
#   ## If there was an error running the statement, it will be raised.
#   ## If it was a successful INSERT statement, .lastID will be the id of the last inserted row
#   new(result)
#   assert(not db.isNil, "Database not connected.")
#   when LOGSQL:
#     info "(LOGSQL) " & query.string & " / " & $params
#   when TIMING_MODE:
#     let start_time = getTime()
#   var pstmt = db.prepareAndBindArgs(query, params)
#   if pstmt.step() in {SQLITE_DONE, SQLITE_ROW}:
#     result.lastID = last_insert_rowid(db)
#   if finalize(pstmt) != SQLITE_OK:
#     db.raiseErr()
#   when TIMING_MODE:
#     info "(timing.sql) " & $(getTime()-start_time).inMilliseconds() & "ms " & query.string

# proc executeMany*(db:DbConn, statements:openArray[string]) =
#   ## Execute many SQL statements.
#   ## Return any error as a string.
#   assert(not db.isNil, "Database not connected.")
#   var pstmt:PStmt
#   for s in statements:
#     try:
#       when LOGSQL:
#         info "(LOGSQL) " & s
#       when TIMING_MODE:
#         let start_time = getTime()
#       let querystring = s.string
#       if db.prepare_v2(querystring, querystring.len.cint, pstmt, nil) != SQLITE_OK:
#         db.raiseErr()
#       # if clear_bindings(pstmt) != SQLITE_OK:
#       #   db.raiseErr()
#       if pstmt.step() notin {SQLITE_DONE, SQLITE_ROW}:
#         let err1 = db.currentErrMsg()
#         if pstmt.finalize() != SQLITE_OK:
#           db.raiseErr(err1)
#         db.raiseErr()
#       if finalize(pstmt) != SQLITE_OK:
#         db.raiseErr()
#       when TIMING_MODE:
#         info "(timing.sql) " & $(getTime()-start_time).inMilliseconds() & "ms " & querystring
#     except:
#       raise
