#!/bin/bash -ex

lsmod | grep kvm >/dev/null && {
    sudo modprobe -r kvm_intel
    sudo modprobe -r kvm
}

sudo modprobe kvm
sudo modprobe kvm_intel hlat=0 pw=1 gpv=1