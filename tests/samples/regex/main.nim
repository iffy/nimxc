import std/re
import std/sequtils
# copied from the regex docs
doAssert "var1=key; var2=key2".replace(re"(\w+)=(\w+)") == "; "
doAssert "var1=key; var2=key2".replace(re"(\w+)=(\w+)", "?") == "?; ?"
doAssert toSeq(split("00232this02939is39an22example111", re"\d+")) == @["", "this", "is", "an", "example", ""]
