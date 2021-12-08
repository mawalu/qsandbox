import strformat
import parseopt
import osproc
import posix
import linux
import os

# should be in the linux module but seems to be missing
const CLONE_NEWUSER = 0x10000000'i32

# c bindings
proc unshare(flag: cint): cint {.importc, header: "<sched.h>"}

proc mount(source: cstring, target: cstring, filesystemtype: cstring,
           mountflags: culong, data: pointer): cint {.importc, header:"<sys/mount.h>"}

const
  UID_MAP = "/proc/self/uid_map"
  GID_MAP = "/proc/self/gid_map"
  SETGROUPS = "/proc/self/setgroups"

proc virtiofsd(paths: seq[string]): Pid =
  let uid = getuid()
  let gid = getgid()
  let pid = fork()

  if pid < 0:
    raise newException(OSError, "Fork failed")

  if pid > 0:
    # we are the parent
    return pid

  # create new mount namespace
  if unshare(CLONE_NEWUSER or CLONE_NEWNS) != 0:
    raise newException(OSError, "Unshare failed")

  # map our uid to root
  writeFile(UID_MAP, &"0 {uid} 1")
  writeFile(SETGROUPS, "deny")
  writeFile(GID_MAP, &"0 {gid} 1")

  # create a tmpfs in /var/run so virtiofsd can write there
  if mount(cstring("tmpfs"), cstring("/var/run"), cstring("tmpfs"), 0, cstring("")) != 0:
    raise newException(OSError, "Mount failed")

  # start a virtiofsd process for each mount
  var procs {.threadvar.}: seq[Process]

  for i, path in paths:
    procs.add(startProcess(
      command = "/usr/lib/qemu/virtiofsd",
      args = @[&"--socket-path=/tmp/mount.{i}.sock", "-o", &"source={path}"],
      options = {poParentStreams}
    ))

  onSignal(SIGTERM):
    for process in procs:
      terminate(process)

    quit(0)

  for process in procs:
    discard waitForExit(process)

  quit(0)

proc qemu*(args: OptParser) =
  let childPid = virtiofsd(@["/tmp", "/home"])

  let args = @[
    "-enable-kvm", "-cpu", "host", "-m", "512m", "-smp", "2",
    "-kernel", "/home/martin/code/qemu/build-image/image/vmlinuz-linux",
    "-append", "earlyprintk=ttyS0 console=ttyS0 root=/dev/vda rw quiet",
    "-initrd" , "/home/martin/code/qemu/build-image/image/initramfs-linux-custom.img",
    "-m", "4G", "-object", "memory-backend-file,id=mem,size=4G,mem-path=/dev/shm,share=on", "-numa", "node,memdev=mem",
    "-device", "virtio-rng-pci",
    "-bios", "/usr/share/qemu/qboot.rom",
    "-drive", "if=virtio,file=/home/martin/code/qemu/build-image/image/image.qcow2",
    "-netdev", "user,id=net0,hostfwd=tcp::2222-:22",
    "-device", "virtio-net-pci,netdev=net0",
    "-nodefaults", "-no-user-config", "-nographic",
    "-chardev", "socket,id=share.1,path=/tmp/mount.0.sock",
    "-device", "vhost-user-fs-pci,queue-size=1024,chardev=share.1,tag=share.1",
    "-serial", "stdio"
  ]

  let qemu = startProcess(
    command = "qemu-system-x86_64",
    options = {poParentStreams, poUsePath},
    args = args
  )

  discard waitForExit(qemu)

  discard kill(childPid, SIGTERM)
  discard waitPid(childPid,cast[var cint](nil),0)
