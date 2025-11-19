#!/bin/bash -e

distribution=bookworm
l1_size=16384

git submodule update --init

./common.sh -t qemu -l l0 -d ${distribution}
./common.sh -t image -l l1 -d ${distribution} -s ${l1_size}

./common.sh -t linux -l l0
./common.sh -t linux -l l1

./common.sh -t kernel -l l0
./common.sh -t kernel -l l1

./common.sh -t initrd -l l1

./common.sh -t vm

./common.sh -t kvm -l l0
pushd kvm-l0 >/dev/null
./build.sh
popd >/dev/null

echo "[*] Setup done."
