#!/bin/bash -e

KERNEL=linux-l2/arch/x86/boot/bzImage
INITRD=linux-l2/initrd.img-l2

IMG=images/l2.img
LINUX_L2=linux-l2
SCRIPTS=scripts
L2_DATA=l2-data
QEMU=$PWD/build-qemu-l1/qemu-system-x86_64

run_qemu() {
    local mem=$1
    local smp=$2
    local ssh_port=11032
    local debug_port=1234

    qemu_str=""

    cmdline="console=ttyS0 root=/dev/sda rw earlyprintk=serial net.ifnames=0 pci=earlydump debug"

    vfio_str=""
    if [[ ! -z $VFIO ]];
    then
        # bdf=$(lspci | grep Unclassified | cut -d' ' -f1)
        # if [[ -z ${bdf} ]];
        # then
        # 	echo "[-] cannot find Unclassified device"
        # 	exit 0
        # fi
        bdf=00:06.0

        vfio_str+="-device \"vfio-pci,host=${bdf}\" \\"
        vfio_str+="-virtfs local,path=edu-driver,mount_tag=edu-driver,security_model=passthrough,id=edu-driver \\"
    fi

    debug_str=""
    if [[ ! -z $DEBUG ]];
    then
        debug_str="-S -gdb tcp::${debug_port} \\"
    fi

    qemu_str+="${QEMU} -cpu host -enable-kvm \\"
    qemu_str+="-m ${mem} -smp ${smp} \\"

    qemu_str+="-drive format=raw,file=${IMG} \\"

    qemu_str+="-device virtio-net-pci,netdev=net0 \\"
    qemu_str+="-netdev user,id=net0,host=10.0.2.10,hostfwd=tcp::${ssh_port}-:22 \\"

    qemu_str+="-virtfs local,path=${SCRIPTS},mount_tag=${SCRIPTS},security_model=passthrough,id=${SCRIPTS} \\"
    qemu_str+="-virtfs local,path=${L2_DATA},mount_tag=${L2_DATA},security_model=passthrough,id=${L2_DATA} \\"
    
    qemu_str+="-append \"${cmdline}\" \\"
    qemu_str+="-kernel ${KERNEL} \\"
    qemu_str+="-initrd ${INITRD} \\"
    qemu_str+=${vfio_str}
    qemu_str+=${debug_str}
    qemu_str+="-vga none -nodefaults -nographic "
    qemu_str+="-serial mon:stdio"

    eval ${qemu_str}
}

usage() {
  echo "Usage: $0 [-m <mem>] [-s <smp>]" 1>&2
  echo "Options:" 1>&2
  echo "  -m <mem>              Specify the memory size" 1>&2
  echo "                               - default: 4g" 1>&2
  echo "  -s <smp>              Specify the SMP" >&2
  echo "                               - default: 4" 1>&2
  exit 1
}

mem=4g
smp=4
ssh_port=$L1_SSH_PORT
gdb_port=$L1_GDB_PORT

while getopts ":hm:s:" opt; do
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
        \?)
            echo "Invalid option: -$OPTARG" >&2
            usage
            ;;
    esac
done

shift $((OPTIND -1))

run_qemu ${mem} ${smp}