import parseopt

import commands/help
import commands/list
import commands/qemu
import commands/run
import commands/ssh

proc cmd (options: OptParser) =
  case options.key:
    of "qemu":
      qemu(options)
    of "run":
      run(options)
    of "ssh":
      ssh(options)
    of "list":
      list(options)
    else:
      help(options)

proc main () =
  var options = initOptParser()
  options.next()

  case options.kind
  of cmdEnd: help(options)
  of cmdShortOption, cmdLongOption:
    echo "Unkown argument"
    quit(1)
  of cmdArgument:
    cmd(options)

main()