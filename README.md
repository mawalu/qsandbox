# qemu-sandbox

PoC shell sandboxing using QEMU and virtiofsd.

## Installation

Clone the repo and link `qsandbox` somewhere in your path. The script currently expects the `image` and `ssh` folder next to its location on disk.

## Setup

You'll need a few things for the script to work:

 * A ssh key pair in `ssh/qemu_ssh` & `ssh/qemu_ssh.pub`. You can link your default key pair or use the chance to generate one without a passphrase.
 * `image/image.qcow2`, `image/vmlinuz-linux`, `image/initramfs-linux-custom.img`. The `build.sh` script can build these based on arch

These requirements are currently hard coded but should be configurable in the future.

## Usage

```
Usage:
       qsandbox run [dir]  - start sandbox and mount current working dir
       qsandbox list       - list running sandboxes
       qsandbox enter      - open ssh connection to a sandbox
       qsandbox qemu       - start the qemu process for a new sandbox, used by run
```

### `qsandbox run`

Starts a new vm using `systemd-run` and `qsandbox qemu`, mounts the current working dir or the specified directory and opens an ssh session.

### `qsandbox list`

Lists all running sandboxes and their ssh ports.

### `qsandbox enter`

A wrapper around `ssh`. Takes port as only argument but defaults to `5555`.

### `qsandbox qemu`

Starts the actual sandbox.

## Accessing the sandbox

By default, QEMU exposes to ports for each sandbox. An ssh port (starting at `5555`) and an "app port" that can be used by some app in the vm (starting at `8000`). Ports should be configurable in the future.

## Tips for custom images

Mount the default share automatically:

```
echo -e "share.1\t/mnt\tvirtiofs\trw,_netdev\t0\t0" >> /etc/fstab
```

Disable auth on the QEMU serial console:

```
mkdir -p /etc/systemd/system/serial-getty@ttyS0.service.d
echo -e "[Service]\nExecStart=\nExecStart=-/usr/bin/agetty --autologin root -s %I 115200,38400,9600 vt102" > /etc/systemd/system/serial-getty@ttyS0.service.d/autologin.conf
````

# License

MIT
