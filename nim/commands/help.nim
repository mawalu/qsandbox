import std/strformat
import std/parseopt
import os

proc help*(args: OptParser) =
  let bin = lastPathPart(getAppFilename())

  echo "qsandbox - temporary sandboxes using qemu"
  echo ""
  echo "Usage:"
  echo &"   {bin} run   - start sandbox and mount current working dir"
  echo &"   {bin} list  - list running sandboxes"
  echo &"   {bin} enter - open ssh connection to a sandbox"
  echo &"   {bin} qemu  - start the qemu process for a new sandbox, used by run"

  quit(0)