#!/bin/bash
CURRENT_KERNEL_VERSION=5.10
CFG_PATH_DEFAULT=./res
CFG_TMP_DIR=./.temp

CFG_DEBUG_LIST_FILE=$CFG_PATH_DEFAULT/debug_list.load
CFG_KERNEL_DRIVERS_PATH=../kernel-$CURRENT_KERNEL_VERSION
CFG_SAMPLE_BOOTIMG=./prebuilts/boot-$CURRENT_KERNEL_VERSION.img
CFG_VENDOR_RAMDISK_LOAD_FILE=$CFG_PATH_DEFAULT/vendor_ramdisk_modules.load
CFG_VENDOR_BOOTCONFIG_FILE=$CFG_PATH_DEFAULT/bootconfig

TMP_BOOT_DIR=$CFG_TMP_DIR/boot
TMP_MODULES_PATH=$CFG_TMP_DIR/lib/modules/0.0
TMP_VENDOR_RAMDISK_FILE=out/vendor_ramdisk.cpio.gz
TMP_KERNEL_IMAGE=$TMP_BOOT_DIR/kernel

OUT_VENDOR_BOOT_FILE=out/vendor_boot.img
OUT_BOOT_FILE=out/boot.img
OUT_VENDOR_RAMDISK_DIR=./vendor_ramdisk
OUT_MODULE_DIR=$OUT_VENDOR_RAMDISK_DIR/lib/modules

readonly OBJCOPY_BIN=llvm-objcopy
readonly USE_STRIP=1

if [ -z $MY_DTB ]; then
  DTB_PATH=$CFG_KERNEL_DRIVERS_PATH/arch/arm64/boot/dts/rockchip/rk3588-evb1-lp4-v10.dtb
else
  DTB_PATH=$CFG_KERNEL_DRIVERS_PATH/arch/arm64/boot/dts/rockchip/$MY_DTB.dtb
fi

export PATH=$PATH:./bin

# $1 origin path
# $2 target path
objcopy() {
    if [ ! -f $1 ]; then
        echo "NOT FOUND!"
        return
    fi
    local module_name=`basename -a $1`
    local OBJCOPY_ARGS=""
    if [ $USE_STRIP = "1" ]; then
        OBJCOPY_ARGS="--strip-debug"
    fi
    $OBJCOPY_BIN $OBJCOPY_ARGS $1 $2$module_name
}

clean_file() {
    if [ -f $1 ]; then
        echo "cleaning file $1"
        rm -rf $1
    fi
    if [ -d $1 ]; then
        echo "cleaning dir $1"
        rm -rf $1
    fi
}

create_dir() {
    if [ ! -d $1 ]; then
        mkdir -p $1
    fi
}

copy_from_load_file() {
    TMP_LOAD_FILE=$1
    TMP_SOURCE_PATH=$2
    echo -e "\033[33mRead modules list from $TMP_LOAD_FILE\033[0m"
    modules_ramdisk_array=($(cat $TMP_LOAD_FILE))
    for MODULE in "${modules_ramdisk_array[@]}"
    do
        module_file=($(find $TMP_SOURCE_PATH -name $MODULE))
        echo "Copying $module_file"
        objcopy $module_file $TMP_MODULES_PATH/
    done
}

echo "==========================================="
echo "Preparing $CFG_TMP_DIR dirs and use placeholder 0.0..."
clean_file system
clean_file $CFG_TMP_DIR
clean_file $OUT_VENDOR_BOOT_FILE
clean_file $TMP_VENDOR_RAMDISK_FILE
create_dir system
create_dir out
create_dir $TMP_MODULES_PATH
echo "Prepare $CFG_TMP_DIR dirs done."
echo "==========================================="
echo -e "\033[33mUse DTS as $DTB_PATH\033[0m"

if [ -z $COPY_ALL_KO ]; then
copy_from_load_file $CFG_VENDOR_RAMDISK_LOAD_FILE $OUT_MODULE_DIR
copy_from_load_file $CFG_DEBUG_LIST_FILE $CFG_KERNEL_DRIVERS_PATH
else
copy_from_load_file $CFG_VENDOR_RAMDISK_LOAD_FILE $CFG_KERNEL_DRIVERS_PATH
fi

echo "Generating depmod..."
depmod -b $CFG_TMP_DIR 0.0
echo "Generate depmod done."

clean_file $OUT_MODULE_DIR
create_dir $OUT_MODULE_DIR
mv $TMP_MODULES_PATH/* $OUT_MODULE_DIR/
cp $CFG_VENDOR_RAMDISK_LOAD_FILE $OUT_MODULE_DIR/modules.load -f
rm -rf $OUT_MODULE_DIR/modules.*.bin
clean_file $OUT_MODULE_DIR/modules.symbols
clean_file $OUT_MODULE_DIR/modules.devname

echo "==========================================="
echo "unpacking $CFG_SAMPLE_BOOTIMG..."
unpack_bootimg --boot_img $CFG_SAMPLE_BOOTIMG --out $TMP_BOOT_DIR
echo "unpack $CFG_SAMPLE_BOOTIMG done."

echo "==========================================="
echo "making vendor_ramdisk..."
mkbootfs -d ./system $OUT_VENDOR_RAMDISK_DIR | minigzip > $TMP_VENDOR_RAMDISK_FILE
echo "make vendor_ramdisk done."

echo "==========================================="
echo "making vendor_boot image..."
mkbootimg --dtb $DTB_PATH --vendor_cmdline "console=ttyFIQ0 firmware_class.path=/vendor/etc/firmware init=/init rootwait ro loop.max_part=7 bootconfig buildvariant=userdebug" --header_version 4 --vendor_bootconfig $CFG_VENDOR_BOOTCONFIG_FILE --vendor_ramdisk $TMP_VENDOR_RAMDISK_FILE --vendor_boot $OUT_VENDOR_BOOT_FILE
echo "make vendor_boot image done."
echo "==========================================="

echo "making boot image..."
mkbootimg --kernel $TMP_KERNEL_IMAGE --ramdisk $TMP_BOOT_DIR/ramdisk --os_version 12 --os_patch_level 2022-09-05 --header_version 4 --output $OUT_BOOT_FILE
echo "make boot image done."
echo "==========================================="
