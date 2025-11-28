# Honmoon: Intel VT-rp Research Project

## Objective
This project aims to implement and evaluate a guest kernel page table protection
system using Intel VT-rp, specifically leveraging HLAT (Hypervisor-Managed
Linear Address Translation) and VPW (Verify Paging-Write) features.

## Hardware Requirements
**Note:** This project requires specific hardware support for Intel VT-rp.
-   **Desktop Processors:** A subset of Elder Lake or later generations.
-   **Server Processors:** A subset of Granite Rapids or later generations.

Ensure your host CPU supports these features before attempting to run the
environment.

## Setup Guide

To set up the entire environment, including building the host/guest kernels and
QEMU, run the setup script:

```bash
./setup.sh
```

**Warning:** The `setup.sh` script builds and installs a new host kernel.
Please proceed with caution on production machines.

After the setup is done, execute `launch-vm.sh` to run the VM.

## TODO

- GPV (Guest Paging Verification) feature is misimplemented in the host, failing to detect page aliasing attacks.
