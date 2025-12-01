# Honmoon

An Intel VT-rp research project for fun.

## Overview

Honmoon is a prototype implementation of Intel VT-rp support within a Linux and
QEMU/KVM environment. It aims to enforce the immutability of kernel code
mappings after boot.

## Hardware Requirements

The host machine must support Intel VT-rp feature.

-   **Desktop Processors:** A subset of Alder Lake (12th gen) or newer
-   **Server Processors:** A subset of Granite Rapids (Xeon 6) or newer

## Setup Guide

To set up the entire environment, we provide a setup script that fetches
submodules and builds them.

```bash

git clone https://github.com/jongukc/honmoon
cd honmoon
./setup.sh
```

**Note:** The `setup.sh` script installs a new host kernel.
Please proceed with caution on production machines.

After the setup is done, reboot with the newly installed kernel, then execute
the launch script.

``` bash
./launch-vm.sh
```

## Directory Structure

- `linux-l0`: The host kernel (runs on bare metal)
- `linux-l1`: The guest kernel (runs inside the VM)
- `qemu-l0`: Modified QEMU with VT-rp support

**Shell scripts and directory structure of this project were adapted from
[OpenTDX](https://github.com/sslab-gatech/open-tdx)**
