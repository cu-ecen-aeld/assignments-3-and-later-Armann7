#!/bin/bash
# Script outline to install and build kernel.
# Author: Siddhant Jajoo.

set -e
set -u
SOURCE_FILE=`readlink -e "$0"`
SOURCE_DIR=`dirname "$SOURCE_FILE"`

if [ "$#" -eq  "0" ]
then
    OUTDIR=/tmp/aeld
else
    OUTDIR=$1
fi

KERNEL_REPO=git://git.kernel.org/pub/scm/linux/kernel/git/stable/linux-stable.git
KERNEL_VERSION=v5.15.163
BUSYBOX_VERSION=1_33_1
FINDER_APP_DIR=$(realpath $(dirname $0))
ARCH=arm64
CROSS_COMPILE=aarch64-none-linux-gnu-

if [ $# -lt 1 ]
then
	echo "Using default directory ${OUTDIR} for output"
else
	OUTDIR=$1
	echo "Using passed directory ${OUTDIR} for output"
fi

mkdir -p ${OUTDIR}

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/linux-stable" ]; then
    #Clone only if the repository does not exist.
	echo "CLONING GIT LINUX STABLE VERSION ${KERNEL_VERSION} IN ${OUTDIR}"
	git clone ${KERNEL_REPO} --depth 1 --single-branch --branch ${KERNEL_VERSION}
fi
if [ ! -e ${OUTDIR}/linux-stable/arch/${ARCH}/boot/Image ]; then
    cd linux-stable
    echo "Checking out version ${KERNEL_VERSION}"
    git checkout ${KERNEL_VERSION}
    # TODO: Add your kernel build steps here
    make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE mrproper
    make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE defconfig
    make -j4 ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE all
    # make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE modules
    # make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE dtbs
fi

echo "Adding the Image in outdir"
cp -f ${OUTDIR}/linux-stable/arch/arm64/boot/Image* ${OUTDIR}/

echo "Creating the staging directory for the root filesystem"
cd "$OUTDIR"
if [ -d "${OUTDIR}/rootfs" ]
then
	echo "Deleting rootfs directory at ${OUTDIR}/rootfs and starting over"
    sudo rm  -rf ${OUTDIR}/rootfs
fi

# TODO: Create necessary base directories
mkdir rootfs 

cd "$OUTDIR"
if [ ! -d "${OUTDIR}/busybox" ]
then
    git clone git://busybox.net/busybox.git
    cd busybox
    git checkout ${BUSYBOX_VERSION}
    # TODO:  Configure busybox
    make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE defconfig
    # make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE menuconfig
    make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE
else
    cd busybox
fi

# TODO: Make and install busybox
make CONFIG_PREFIX=${OUTDIR}/rootfs ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE install
cd $OUTDIR/rootfs
mkdir -p {bin,dev,sbin,etc,proc,sys/kernel/debug,usr/{bin,sbin,lib},lib,lib64,mnt/root,root,home,var/log}

echo "Library dependencies"
${CROSS_COMPILE}readelf -a bin/busybox | grep "program interpreter"
${CROSS_COMPILE}readelf -a bin/busybox | grep "Shared library"

# TODO: Add library dependencies to rootfs
SYSROOT=$(${CROSS_COMPILE}gcc -print-sysroot)
echo "sysroot is ${SYSROOT}"
# cp -rf $SYSROOT/* .
cp $SYSROOT/lib/ld-linux-aarch64.so.1 lib/
cp $SYSROOT/lib64/libm.so.6 $SYSROOT/lib64/libresolv.so.2 $SYSROOT/lib64/libc.so.6 lib64/

echo "Make device nodes"
sudo mknod -m 666 dev/null c 1 3
sudo mknod -m 666 dev/tty c 5 0
sudo mknod -m 622 dev/console c 5 1

echo "Clean and build the writer utility"
cd $SOURCE_DIR
make clean
make ARCH=arm64 CROSS_COMPILE=$CROSS_COMPILE

echo "Copy the finder related scripts and executables to the /home directory on the target rootfs"
cp -f writer finder.sh finder-test.sh autorun-qemu.sh conf/* $OUTDIR/rootfs/home/

# TODO: Chown the root directory
sudo chown -R root:root $OUTDIR/rootfs

# TODO: Create initramfs.cpio.gz
cd $OUTDIR/rootfs
sudo find . | cpio -H newc -ov --owner root:root > $OUTDIR/initramfs.cpio
gzip -f $OUTDIR/initramfs.cpio
