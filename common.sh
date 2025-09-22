#!/bin/bash -e

run_cmd()
{
    echo "$*"

    eval "$*" || {
        echo "ERROR: $*"
        exit 1
    }
}

run_mount()
{
    local tmp=$1
    local img=$2

    [ -d ${tmp} ] && {
        echo "Error: ${tmp} already exist, please remove it"
        exit 1
    }
    mkdir -p ${tmp}

    run_cmd sudo mount images/${img}.img ${tmp}
    sleep 1
}

run_umount()
{
    local tmp=$1

    run_cmd sudo umount ${tmp}
    run_cmd rm -rf ${tmp} -v
}

run_chroot()
{
    root=$1
    script=$2
    nocheck=$3

    sudo chroot ${root} /bin/bash -c """
set -ex
${script}
exit
"""
    if [ -z $nocheck ] && [ $? -ne 0 ]; then
        echo "ERROR: chroot failed"
        exit 1
    fi
}

build_qemu()
{
    local vm_level=$1
    local distribution=$2
    local version=$3

    NUM_CORES=$(nproc)
    MAX_CORES=$(($NUM_CORES - 1))

    [ -d "qemu-${vm_level}" ]  || {
        run_cmd wget https://download.qemu.org/qemu-${version}.tar.xz
        run_cmd tar xvJf qemu-${version}.tar.xz
        run_cmd mv qemu-${version} qemu-${vm_level}
        run_cmd rm qemu-${version}.tar.xz
    }

    if [ ${vm_level} = "l0" ];
    then
        sudo sed -i 's/# deb-src/deb-src/' /etc/apt/sources.list

        run_cmd sudo apt update
        
        export DEBIAN_FRONTEND=noninteractive
        run_cmd sudo apt install -y build-essential git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev
        run_cmd sudo -E apt build-dep -y qemu
        run_cmd sudo apt install -y libaio-dev libbluetooth-dev libbrlapi-dev libbz2-dev
        run_cmd sudo apt install -y libsasl2-dev libsdl1.2-dev libseccomp-dev libsnappy-dev libssh2-1-dev
        run_cmd sudo apt install -y python3 python-is-python3 python3-venv 

        mkdir -p qemu-${vm_level}/build
        pushd qemu-${vm_level}/build > /dev/null
        run_cmd ../configure --target-list=x86_64-softmmu --enable-slirp --disable-werror
        make -j$MAX_CORES
        popd > /dev/null
    else # l1
        [ -f images/${vm_level}.img ] || {
            echo "Error: ${vm_level}.img not existing"
            exit 1
        }

        tmp=$(realpath tmp)
        run_mount ${tmp} ${vm_level}

        run_cmd sudo mkdir ${tmp}/root/qemu-${vm_level}
        run_cmd sudo mkdir ${tmp}/root/build-qemu-${vm_level}

        run_cmd sudo mount --bind qemu-${vm_level} ${tmp}/root/qemu-${vm_level}

        run_chroot ${tmp} """
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'deb-src https://deb.debian.org/debian ${distribution} main non-free-firmware' >> /etc/apt/sources.list

apt update

export DEBIAN_FRONTEND=noninteractive

apt install -y build-essential git libglib2.0-dev libfdt-dev libpixman-1-dev zlib1g-dev
apt build-dep -y qemu
apt install -y libaio-dev libbluetooth-dev libbrlapi-dev libbz2-dev
apt install -y libsasl2-dev libsdl1.2-dev libseccomp-dev libsnappy-dev libssh2-1-dev
apt install -y python3 python-is-python3 python3-venv

cd /root/build-qemu-${vm_level}
../qemu-${vm_level}/configure --target-list=x86_64-softmmu --enable-kvm --enable-slirp --disable-werror
make -j ${MAX_CORES}
"""

        run_cmd sudo umount ${tmp}/root/qemu-${vm_level}
        run_cmd sudo rm -rf ${tmp}/root/qemu-${vm_level}
        run_umount ${tmp}
    fi

    
}

build_image()
{
    local vm_level=$1
    local distribution=$2
    local size=$3

    if [ ${vm_level} = "l0" ]
    then
        echo "Error: build_image not supported for ${vm_level}"
        exit 1
    fi


    run_cmd sudo apt install -y debootstrap

    pushd images > /dev/null

    run_cmd chmod +x create-image.sh

    echo "[+] Build ${image} image ..."

    run_cmd ./create-image.sh -d ${distribution} -s ${size}
    run_cmd mv ${distribution}.img ${vm_level}.img
    run_cmd mv ${distribution}.id_rsa ${vm_level}.id_rsa
    run_cmd mv ${distribution}.id_rsa.pub ${vm_level}.id_rsa.pub

    popd > /dev/null
}

build_kernel()
{
    local vm_level=$1
    
    NUM_CORES=$(nproc)
    MAX_CORES=$(($NUM_CORES - 1))

    run_cmd sudo apt install -y git fakeroot build-essential ncurses-dev xz-utils libssl-dev bc flex libelf-dev bison

    [ ! -d linux-${vm_level} ] && {
        echo "Error : linux-${vm_level} not found"
        exit 1
    }

    MAKE="make -C linux-${vm_level} -j$MAX_CORES LOCALVERSION="
    run_cmd sudo $MAKE distclean

    pushd linux-${vm_level} > /dev/null
    if [ ${vm_level} = "l0" ];
    then
        [ -f /boot/config-$(uname -r) ] || {
            echo "Error: /boot/config-$(uname -r) not found"
            exit 1
        }
        run_cmd cp -f /boot/config-$(uname -r) .config

        ./scripts/config --enable CONFIG_EXPERT
    else
        run_cmd make defconfig
        run_cmd make kvm_guest.config

        run_cmd ./scripts/config --enable CONFIG_CONFIGFS_FS
        run_cmd ./scripts/config --enable CONFIG_DEBUG_INFO_DWARF5
        run_cmd ./scripts/config --enable CONFIG_DEBUG_INFO
        run_cmd ./scripts/config --disable CONFIG_RANDOMIZE_BASE
        run_cmd ./scripts/config --enable CONFIG_GDB_SCRIPTS

        run_cmd ./scripts/config --module CONFIG_KVM
        run_cmd ./scripts/config --module CONFIG_KVM_INTEL
        run_cmd ./scripts/config --module CONFIG_KVM_AMD
        run_cmd ./scripts/config --enable CONFIG_KVM_VFIO

	    run_cmd ./scripts/config --enable CONFIG_VFIO
    	run_cmd ./scripts/config --enable CONFIG_VFIO_GROUP
    	run_cmd ./scripts/config --enable CONFIG_VFIO_CONTAINER
    	run_cmd ./scripts/config --enable CONFIG_VFIO_IOMMU_TYPE1
	    run_cmd ./scripts/config --enable CONFIG_VFIO_VIRQFD 

	    run_cmd ./scripts/config --enable CONFIG_VFIO_PCI_CORE
    	run_cmd ./scripts/config --enable CONFIG_VFIO_PCI_MMAP
    	run_cmd ./scripts/config --enable CONFIG_VFIO_PCI_INTX
    	run_cmd ./scripts/config --enable CONFIG_VFIO_PCI
    fi
    popd > /dev/null
    run_cmd $MAKE olddefconfig

    echo "[+] Build linux kernel ..."
    run_cmd $MAKE
}

install_kernel()
{
    local vm_level=$1

    NUM_CORES=$(nproc)
    MAX_CORES=$(($NUM_CORES - 1))

    [ -f linux-${vm_level}/arch/x86/boot/bzImage ] || {
        echo "Error: linux-${vm_level} not built"
        exit 1
    }

    local vm_level=$1

    check_argument "-l" "vm_level" ${vm_level}

    run_cmd sudo apt install -y rsync grub2

    NUM_CORES=$(nproc)
    MAX_CORES=$(($NUM_CORES - 1))

    [ -f linux-${vm_level}/arch/x86/boot/bzImage ] || {
        echo "Error: linux-${vm_level} not built"
        exit 1
    }

    version=$(cat linux-${vm_level}/include/config/kernel.release)

    if [ ${vm_level} = "l0" ];
    then
        pushd linux-${vm_level} >/dev/null

        run_cmd sudo make -j${MAX_CORES} INSTALL_MOD_STRIP=1 modules_install
        run_cmd sudo make -j${MAX_CORES} headers_install
        run_cmd sudo make install

        popd >/dev/null

        sudo sed -i "s/GRUB_TIMEOUT=0/GRUB_TIMEOUT=10/g" /etc/default/grub
        sudo sed -i "s/GRUB_TIMEOUT_STYLE=hidden/GRUB_TIMEOUT_STYLE=menu/g" /etc/default/grub
        run_cmd sudo update-grub
    else
        [ -f images/${vm_level}.img ] || {
            echo "Error: images/${vm_level}.img not found"
            exit 1
        }

        tmp=$(realpath tmp)
        run_mount ${tmp} ${vm_level}

        pushd linux-${vm_level} > /dev/null

        run_cmd sudo rm -rf ${tmp}/usr/src/linux-headers-${version}
        [ -d ${tmp}/usr/src/linux-headers-${version}/arch/x86 ] || {
            run_cmd sudo mkdir -p ${tmp}/usr/src/linux-headers-${version}/arch/x86
        }
        [ -d ${tmp}/usr/src/linux-headers-${version}/arch/x86 ] && {
            run_cmd sudo cp arch/x86/Makefile* ${tmp}/usr/src/linux-headers-${version}/arch/x86
            run_cmd sudo cp -r arch/x86/include ${tmp}/usr/src/linux-headers-${version}/arch/x86
        }
        run_cmd sudo cp -r include ${tmp}/usr/src/linux-headers-${version}
        run_cmd sudo cp -r scripts ${tmp}/usr/src/linux-headers-${version}

        [ -d ${tmp}/usr/src/linux-headers-${version}/tools/objtool ] || {
            run_cmd sudo mkdir -p ${tmp}/usr/src/linux-headers-${version}/tools/objtool
        }

        [ -d ${tmp}/usr/src/linux-headers-${version}/tools/objtool ] && {
            run_cmd sudo cp tools/objtool/objtool ${tmp}/usr/src/linux-headers-${version}/tools/objtool
        }

        run_cmd sudo rm -rf ${tmp}/lib/modules/${version}

        run_cmd sudo make -j${MAX_CORES} INSTALL_MOD_PATH=${tmp} modules_install
        run_cmd sudo make -j${MAX_CORES} INSTALL_HDR_PATH=${tmp} headers_install

        run_cmd sudo mkdir -p ${tmp}/usr/lib/modules/${version}

        run_cmd sudo rm -rf ${tmp}/usr/lib/modules/${version}/source
        run_cmd sudo ln -s /usr/src/linux-headers-${version} ${tmp}/usr/lib/modules/${version}/source
        run_cmd sudo rm -rf ${tmp}/usr/lib/modules/${version}/build
        run_cmd sudo ln -s /usr/src/linux-headers-${version} ${tmp}/usr/lib/modules/${version}/build

        run_cmd sudo cp Module.symvers ${tmp}/usr/src/linux-headers-${version}/Module.symvers
        run_cmd sudo cp Makefile ${tmp}/usr/src/linux-headers-${version}/Makefile

        popd > /dev/null

        run_umount ${tmp}
    fi
}

build_initrd()
{
    local vm_level=$1
    local image=$2

    if [ ${vm_level} = "l0" ]
    then
        echo "Error: build_initrd not supported for ${vm_level}"
        exit 1
    fi

    [ -f linux-${vm_level}/arch/x86/boot/bzImage ] || {
        echo "Error: linux-${vm_level} not built"
        exit 1
    }

    version=$(cat linux-${vm_level}/include/config/kernel.release)
    tmp=$(realpath tmp)
    run_mount ${tmp} ${vm_level}

    [ -d linux-${vm_level} ] || {
        echo "[-] Cannot find linux-${vm_level}"
        exit 1
    }

    [ -f linux-${vm_level}/.config ] || {
        echo "[-] Cannot find linux-${vm_level}/.config"
        exit 1
    }

    run_cmd sudo cp linux-${vm_level}/.config ${tmp}/boot/config-${version}

    run_chroot ${tmp} """
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
apt update

export DEBIAN_FRONTEND=noninteractive
apt install -y initramfs-tools

set +ex
PATH=/usr/sbin/:\$PATH update-initramfs -k ${version} -c -b /boot/
""" 

    run_cmd sudo cp ${tmp}/boot/initrd.img-${version} linux-${vm_level}/initrd.img-${vm_level}

    run_umount ${tmp}
}

extract_kvm()
{
    local vm_level=$1
    kvm=kvm-${vm_level}

    [ -d $kvm ] || {
        mkdir -p $kvm
    }
    rm -rf $kvm/*

    echo "yes"

    for f in $(ls linux-${vm_level}/arch/x86/kvm/*.c)
    do
        run_cmd ln -s $PWD/$f $kvm/$(basename $f)
    done

    for f in $(ls linux-${vm_level}/arch/x86/kvm/*.h)
    do
        run_cmd ln -s $PWD/$f $kvm/$(basename $f)
    done

    for d in $(ls -d linux-${vm_level}/arch/x86/kvm/*/)
    do
        run_cmd ln -s $PWD/$d $kvm/$(basename $d)
    done

    run_cmd ln -s $PWD/linux-${vm_level}/virt $kvm/virt

    targets=""
    for f in $(ls linux-${vm_level}/virt/kvm/*.c)
    do
        target=${f%.?}.o
        if [ $(basename $target) = "guest_memfd.o" ]
        then
            continue
        fi
        targets+="virt\/kvm\/$(basename $target) "
    done

    run_cmd ln -s $PWD/linux-${vm_level}/arch/x86/kvm/Kconfig $kvm/Kconfig

    run_cmd cp linux-${vm_level}/arch/x86/kvm/Makefile $kvm/Makefile

    sed -i '/ccflags-y/s/$/ -IPWD/' $kvm/Makefile
    sed -i "s|-IPWD|-I"$PWD/$kvm"|g" $kvm/Makefile
    sed -i '/include $(srctree)\/virt\/kvm\/Makefile.kvm/a KVM := virt/kvm' $kvm/Makefile
    sed -i '/include $(srctree)\/virt\/kvm\/Makefile.kvm/s/^/#/' $kvm/Makefile

    sed -i "0,/^kvm-y\s\+[-+]\?=\s\+/s//kvm-y                   += ${targets}\\\''\n                          /" $kvm/Makefile
    sed -i "s/''//g" $kvm/Makefile

    echo "make -j -C $PWD/linux-${vm_level} M=$PWD/$kvm" > $kvm/build.sh
    chmod +x $kvm/build.sh

}

finalize_vms()
{
    if [[ ! -f images/l1.img || ! -f images/l2.img ]]
    then
        echo "Error: images/l1.img,l2.img not found"
        exit 1
    fi

    [ -d l1-data ] || {
        run_cmd mkdir l1-data
    }
    [ -d l2-data ] || {
        run_cmd mkdir l2-data
    }

    tmp=$(realpath tmp)

    run_mount ${tmp} l2

    fstab=""
    for dir in "scripts" "l2-data"
    do
        fstab+="${dir} /root/${dir} 9p trans=virtio,version=9p2000.L 0 0\n"
    done

    echo -ne ${fstab} | sudo tee -a ${tmp}/etc/fstab

    run_umount ${tmp}

    run_mount ${tmp} l1

    run_cmd sudo mkdir -p ${tmp}/root/images
    run_cmd sudo cp images/l2.img ${tmp}/root/images/

    fstab=""
    for dir in "qemu-l1" "kvm-l1" "linux-l2" "scripts" "l1-data" "l2-data"
    do
        fstab+="${dir} /root/${dir} 9p trans=virtio,version=9p2000.L 0 0\n"
    done

    echo -ne ${fstab} | sudo tee -a ${tmp}/etc/fstab

    run_umount ${tmp}
}


# Function to show usage information
usage()
{
  echo "Usage: $0 [-t <target>] [-l <vm_level>] [-d <distribution_version>] [-v <kernel_version>] [-s <image_size>]" 1>&2
  echo "Options:" 1>&2
  echo "  -d <distribution_version>    Specify the distribution version of Debian" 1>&2
  echo "                               - default: bookworm" 1>&2
  echo "  -v <kernel_version>          Specify the Linux kernel version" 1>&2
  echo "                               - default: 6.16.4" 1>&2
  echo "  -s <image_size>              Specify the image size (MB)" 1>&2
  echo "                               - default: 16384 (16G)" 1>&2
  echo "  -t <target>                  Specify which target to run" 1>&2
  echo "                               - options: qemu, image, linux, kernel, initrd, kvm, vm" 1>&2
  exit 1
}

# Default settings
distribution_version="bookworm"
kernel_version="6.16.4"
qemu_version="10.1.0"
image_size="16384"
vm_level="l1"

# Parse command line options
while getopts ":hd:v:s:t:l:" opt; do
  case $opt in
    h)
      usage
      ;;
    d)
      distribution_version=$OPTARG
      echo "Distribution version: $distribution_version"
      ;;
    v)
      kernel_version=$OPTARG
      echo "Kernel version: $kernel_version"
      ;;
    s)
      image_size=$OPTARG
      echo "Image size: $image_size"
      ;;
    t)
      target=$OPTARG
      echo "Target: $target"
      ;;
    l)
      vm_level=$OPTARG
      echo "VM Level: ${vm_level}"
      ;;
    \?)
      echo "Invalid option: -$OPTARG" >&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

shift $((OPTIND -1))

case $target in
    "qemu")
        build_qemu ${vm_level} ${distribution_version} ${qemu_version}
        ;;
    "image")
        build_image ${vm_level} ${distribution_version} ${image_size}
        ;;
    "linux")
        build_kernel ${vm_level}
        ;;
    "kernel")
        install_kernel ${vm_level} ${distribution_version}
        ;;
    "initrd")
        build_initrd ${vm_level} ${distribution_version}
        ;;
    "kvm")
        extract_kvm "l1"
        ;;
    "vm")
        finalize_vms
        ;;
    *)
        echo "Please provide -t <target>"
        ;;
esac

# Print summary of parameters
#summary
