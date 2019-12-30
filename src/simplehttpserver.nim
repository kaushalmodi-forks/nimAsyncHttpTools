## =================
## simplehttpserver
## =================
##
## Description
## -----------
## This is a simple http server for instant filesharing.
## Default behavior is to serves the current working dir.
## `simplehttpserver` has implemented the http range syntax, 
## so (unlike pythons http server) seeking in bigger files is supported!
## ```
##  like: python2 -m SimpleHTTPServer
##  like: python3 -m http.server
##  like: http-server
## ```
##
## 
## Usage
## ------
## ```
## cd /folder/that/i/like/to/serve/
## $ simplehttpserver
## ```
import asynchttpserver, asyncdispatch
import os, strutils, uri, logging
import sending
import templates
import psutil

type 
  MyFileInfo = object
    path: string
    fileInfo: FileInfo
  SimpleHttpServer = object
    base: string
    httpServer: AsyncHttpServer
    listeningAddress: string
    port: Port

proc fileInfos(path: string): seq[MyFileInfo] = 
  for kind, path in walkDir(path):
    var fileInfo = getFileInfo(path)
    let myFileInfo = MyFileInfo(
      path: path,
      fileInfo: fileInfo
    )
    result.add myFileInfo

proc trimBase(path, base: string): string =
  path[base.len..^1]

# proc format(str: string): string =
#   var parts = split(" ")

proc renderPath(base, path: string): string = tmpli """
<html>
  <header>
    <title>$path</title>
    <style>
      table {
        border-collapse: collapse;
      }
      th {
        border-bottom: 2px solid black;
      }
      tr {
        border: 1px solid black;
      }
      tr:nth-child(even) {background: #CCC}
      tr:nth-child(odd) {background: #FFF}
    </style>
  </header>
  <body>
    <h1>Directory listing for: $path</h1>
    <table width=100%>

      <tr>
        <th>Name</th>
        <th>Size</th>
      </tr>

      <tr>
        <td>
          <a href="..">..</a>
        </td>
        <td></td>
      </tr>

      $for file in fileInfos(base / path) {
        <tr>

          <td>
            <a href="$(file.path.trimBase(base))">
              ${let strippedPath = file.path.trimBase(base).extractFilename()}
              $if file.fileInfo.kind == pcFile {
                $(strippedPath)
              } $else {
                $(strippedPath)/
              }
            </a>
          </td>

          <td>
            $(file.fileInfo.size.formatSize(includeSpace = true, prefix = bpColloquial))
          </td>

        </tr>
      }

    </table>
  </body>
</html>
"""

proc renderNotFound(): string = tmpli """
  404 not found
"""

proc newSimpleHttpServer(listeningAddress = "0.0.0.0", port = 8080, base = getCurrentDir()): SimpleHTTPServer =
  result = SimpleHTTPServer()
  result.httpServer = newAsyncHttpServer()
  result.base = base
  result.port = port.Port
  result.listeningAddress = listeningAddress

proc cb(srv: SimpleHTTPServer, req: Request) {.async.} =
  let path = (srv.base / req.url.path).decodeUrl()
  echo "BASE:", srv.base
  echo "PATH:", path
  info "${path}" % ["path", path]
  if path.fileExists:
    # echo "FILE"
    discard await req.sendStaticIfExists(path)
  elif path.dirExists:
    # echo "DIR"
    await req.respond(Http200, renderPath(srv.base, req.url.path))
  else:
    await req.respond(Http404, renderNotFound())

proc serve(simpleHttpServer: SimpleHTTPServer): Future[void] {.async.} =
  await simpleHttpServer.httpServer.serve(Port(8080), 
    proc (req: Request): Future[void] = 
      cb(simpleHttpServer, req)
  )

const help = """
  simplehttpserver -h
  simplehttpserver /path/to/serve
"""

proc cli(srv: var SimpleHTTPServer) =
  if paramCount() > 0:
    case paramStr(1)
    of "-h", "--help":
      echo help
      quit()
    srv.base = paramStr(1)

proc formatLine(address: string, port: Port): string =
  return "-> http://${ip}:${port}" % ["ip", address, "port", $port.int]

proc echoListening(srv: SimpleHTTPServer) =
  echo "SimpleHTTPServer listening on: "
  if srv.listeningAddress == "0.0.0.0":
    for ifname, addresses in net_if_addrs():
      echo ""
      echo ifname & ":"
      for address in addresses:
        echo formatLine(address.address, srv.port)
  else:
    echo formatLine(srv.listeningAddress, srv.port)
  echo ""

when isMainModule:
  var consoleLog = newConsoleLogger(fmtStr="[$date $time] ")
  addHandler(consoleLog)
  var simpleHttpServer = newSimpleHttpServer()
  simpleHttpServer.cli()
  simpleHttpServer.echoListening()
  waitFor simpleHttpServer.serve()


