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

## Scripts Overview

*   **`setup.sh`**: The main entry point for setting up the environment. It
    initializes submodules, builds QEMU, creates disk images, compiles both L0
    (Host) and L1 (Guest) Linux kernels, and prepares the initrd.
*   **`common.sh`**: A helper script containing the core logic for building
    components (QEMU, Linux, images) and managing the build environment. It is
    used by `setup.sh`.
*   **`launch-vm.sh`**: Launches the L1 Guest VM using the custom-built QEMU and
    Kernel. It configures SSH forwarding and GDB debugging ports for
    development.
