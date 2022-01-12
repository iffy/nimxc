import std/httpclient
import std/json
proc main() =
  let client = newHttpClient()
  defer: client.close()
  let resp = client.getContent("https://httpbin.org/get?foo=bar")
  let data = resp.parseJson
  stdout.write(data["args"]["foo"].getStr())
main()

