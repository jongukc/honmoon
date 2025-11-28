#!/bin/bash -e

L1_SSH_PORT=11032
L1_GDB_PORT=1234

QEMU=qemu-l0/build/qemu-system-x86_64
IMG=images/l1.img
KERNEL=linux-l1/arch/x86/boot/bzImage
INITRD=linux-l1/initrd.img-l1

SCRIPTS=scripts
MODULES=modules
L1_DATA=l1-data

run_qemu() {
    local mem=$1
    local smp=$2
    local ssh_port=$3
    local debug_port=$4
    local enable_honmoon=$5

    qemu_str=""

    nested_ssh_port=$((ssh_port + 1))
    nested_debug_port=$((debug_port + 1))

    cmdline="console=ttyS0 root=/dev/sda rw earlyprintk=serial net.ifnames=0 pci=earlydump debug honmoon=${enable_honmoon} "

    debug_str=""
    if [[ ! -z $DEBUG ]];
    then
        debug_str="-S -gdb tcp::${debug_port} \\"
    fi

    iommu_str=""
    if [[ ! -z $IOMMU ]];
    then
        iommu_str="""
    -device intel-iommu,intremap=on,device-iotlb=on \
    -device ioh3420,id=pcie.1,chassis=2 \
    -device virtio-net-pci,bus=pcie.1,netdev=net1,disable-legacy=on,disable-modern=off,iommu_platform=on,ats=on \
    -netdev user,id=net1,host=10.0.2.11,hostfwd=tcp::$(($PORT + 2))-:23 \
    """

        cmdline+=" intel_iommu=on iommu=on"
    fi

    edu_str=""
    if [[ ! -z $EDU ]];
    then
        edu_str=" -device edu \\"
    fi

    qemu_str+="${QEMU} -cpu host,-la57 -machine q35,kernel_irqchip=split -enable-kvm \\"
    qemu_str+="-m ${mem} -smp ${smp} \\"

    qemu_str+="-drive format=raw,file=${IMG} \\"

    qemu_str+="-device virtio-net-pci,netdev=net0 \\"
    qemu_str+="-netdev user,id=net0,host=10.0.2.10,hostfwd=tcp::${ssh_port}-:22,hostfwd=tcp::${nested_ssh_port}-:11032,hostfwd=tcp::${nested_debug_port}-:1234 \\"

    qemu_str+="-virtfs local,path=${L1_DATA},mount_tag=${L1_DATA},security_model=passthrough,id=${L1_DATA} \\"
    qemu_str+="-virtfs local,path=${SCRIPTS},mount_tag=${SCRIPTS},security_model=passthrough,id=${SCRIPTS} \\"
    qemu_str+="-virtfs local,path=${MODULES},mount_tag=${MODULES},security_model=passthrough,id=${MODULES} \\"

    qemu_str+="-append \"${cmdline}\" \\"
    qemu_str+="-kernel ${KERNEL} \\"
    qemu_str+="-initrd ${INITRD} \\"
    qemu_str+=${iommu_str}
    qemu_str+=${edu_str}
    qemu_str+=${debug_str}
    qemu_str+="-nographic -no-reboot"

    eval sudo ${qemu_str}
}

usage() {
  echo "Usage: $0 [-m <mem>] [-s <smp>] [-p <ssh_port>] [-d <debug_port>]" 1>&2
  echo "Options:" 1>&2
  echo "  -m <mem>              Specify the memory size" 1>&2
  echo "                               - default: 16g" 1>&2
  echo "  -s <smp>              Specify the SMP" >&2
  echo "                               - default: 4" 1>&2
  echo "  -p <ssh_port>         Specify the ssh port for l1/l2" 1>&2
  echo "                         port for l2 will be <ssh_port> + 1" 1>&2
  echo "                               - default: 11032" 1>&2
  echo "  -d <debug_port>       Specify the debug port for l1/l2" 1>&2
  echo "                         port for l2 will be <debug_port> + 1" 1>&2
  echo "                               - default: 1234" 1>&2
  exit 1
}

mem=16g
smp=4
enable_honmoon=0
ssh_port=$L1_SSH_PORT
gdb_port=$L1_GDB_PORT

while getopts ":hm:s:p:d:e" opt; do
    case $opt in
        h)
            usage
            ;;
        m)
            mem=$OPTARG
            echo "Memory: ${mem}"
            ;;
        s)
            smp=$OPTARG
            echo "SMP: ${smp}"
            ;;
        p)
            ssh_port=$OPTARG
            echo "SSH Port: ${ssh_port}"
            ;;
        d)
            gdb_port=$OPTARG
            echo "GDB Port: ${gdb_port}"
            ;;
        e)
            enable_honmoon=1
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

shift $((OPTIND -1))

run_qemu ${mem} ${smp} ${ssh_port} ${gdb_port} ${enable_honmoon}