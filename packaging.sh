#!/bin/bash

# you must define TOP, RESULT_DIR, BOOT_DEVICE_TYPE, BOARD_NAME

function get_sd_device_number()
{
    local f="$1"
    local dev_num=$(cat $f | grep /system | tail -n1 | awk '{print $1}' | awk -F'/' '{print $5}')
    dev_num=$(echo ${dev_num#dw_mmc.})
    echo "${dev_num}"
}

function is_sd_device()
{
    local f="$1"
    local tmp=$(cat $f | grep dw_mmc | head -n1)
    if (( ${#tmp} > 0 )); then
        echo "true"
    else
        echo "false"
    fi
}

function is_nand_device()
{
    local f="$1"
    local tmp=$(cat $f | grep ubi | head -n1)
    if (( ${#tmp} > 0 )); then
        echo "true"
    else
        echo "false"
    fi
}

function get_root_device()
{
    local fstab=${RESULT_DIR}/root/fstab.${BOARD_NAME}
    if [ ! -f ${fstab} ]; then
        echo "Error: can't find ${fstab} file... You must build before packaging"
        exit 1
    fi

    local is_sd=$(is_sd_device ${fstab})
    if [ ${is_sd} == "true" ]; then
        ROOT_DEVICE_TYPE="sd$(get_sd_device_number ${fstab})"
    else
        local is_nand=$(is_nand_device ${fstab})
        if [ ${is_nand} == "true" ]; then
            ROOT_DEVICE_TYPE=nand
        else
            echo "Error: can't get ROOT_DEVICE_TYPE... Check ${fstab} file"
            exit 1
        fi
    fi
}

function create_partmap_for_spirom()
{
    local partmap_file=${RESULT_DIR}/partmap.txt
    if [ -f ${partmap_file} ]; then
        rm -f ${partmap_file}
    fi

    echo "flash=eeprom,0:2ndboot:2nd:0x0,0x4000;" > ${partmap_file}
    echo "flash=eeprom,0:bootloader:boot:0x10000,0x70000;" >> ${partmap_file}
    if [ ${ROOT_DEVICE_TYPE} == "nand" ]; then
        echo "flash=nand,0:kernel:raw:0xc00000,0x600000;" >> ${partmap_file}
        echo "flash=nand,0:bootlogo:raw:0x2000000,0x400000;" >> ${partmap_file}
        echo "flash=nand,0:battery:raw:0x2800000,0x400000;" >> ${partmap_file}
        echo "flash=nand,0:update:raw:0x3000000,0x400000;" >> ${partmap_file}
        echo "flash=nand,0:system:ubi:0x4000000,0x20000000;" >> ${partmap_file}
        echo "flash=nand,0:cache:ubi:0x24000000,0x10000000;" >> ${partmap_file}
        echo "flash=nand,0:userdata:ubi:0x34000000,0x0;" >> ${partmap_file}
    else
        local dev_num=${ROOT_DEVICE_TYPE#sd}
        echo "flash=mmc,${dev_num}:boot:ext4:0x00100000,0x04000000;" >> ${partmap_file}
        echo "flash=mmc,${dev_num}:system:ext4:0x04100000,0x28E00000;" >> ${partmap_file}
        echo "flash=mmc,${dev_num}:cache:ext4:0x2CF00000,0x21000000;" >> ${partmap_file}
        echo "flash=mmc,${dev_num}:misc:emmc:0x4E000000,0x00800000;" >> ${partmap_file}
        echo "flash=mmc,${dev_num}:recovery:emmc:0x4E900000,0x01600000;" >> ${partmap_file}
        echo "flash=mmc,${dev_num}:userdata:ext4:0x50000000,0x0;" >> ${partmap_file}
    fi
}

function generate_partitionmap()
{
    local partmap_file=
    if [ -f ${TOP}/device/nexell/${BOARD_NAME}/partmap.txt ]; then
        partmap_file=${TOP}/device/nexell/${BOARD_NAME}/partmap.txt
    else
        if [ ${BOOT_DEVICE_TYPE} == "spirom" ]; then
            create_partmap_for_spirom
            partmap_file=${RESULT_DIR}/partmap.txt
        else
            partmap_file=${TOP}/device/nexell/tools/partmap/partmap_${BOOT_DEVICE_TYPE}.txt
        fi
    fi
    if [ ! -f ${partmap_file} ]; then
        echo "can't find partmap file: ${partmap_file}!!!"
        exit -1
    fi
    cp ${partmap_file} ${RESULT_DIR}/partmap.txt
}

function generate_2ndboot()
{
    local secondboot_dir=${TOP}/linux/pyrope/boot/2ndboot
    local nsih_dir=${TOP}/linux/pyrope/boot/nsih
    local secondboot_file=
    local nsih_file=
    local option_d=other
    local option_p=
    case ${BOOT_DEVICE_TYPE} in
        spirom)
            secondboot_file=${secondboot_dir}/pyrope_2ndboot_${BOARD_NAME}_spi.bin
            nsih_file=${nsih_dir}/nsih_${BOARD_NAME}_spi.txt
            ;;
        sd0 | sd2)
            secondboot_file=${secondboot_dir}/pyrope_2ndboot_${BOARD_NAME}_sdmmc.bin
            nsih_file=${nsih_dir}/nsih_${BOARD_NAME}_sdmmc.txt
            ;;
        nand)
            secondboot_file=${secondboot_dir}/pyrope_2ndboot_${BOARD_NAME}_nand.bin
            nsih_file=${nsih_dir}/nsih_${BOARD_NAME}_nand.txt
            option_d=nand
            option_p="-p 8192"
            ;;
    esac

    if [ ! -f ${secondboot_file} ]; then
        echo "can't find secondboot file: ${secondboot_file}!, check ${secondboot_dir}"
        exit -1
    fi

    if [ ! -f ${nsih_file} ]; then
        echo "can't find nsih file: ${nsih_file}!, check ${nsih_dir}"
        exit -1
    fi

    local secondboot_out_file=$RESULT_DIR/2ndboot.bin

    ${TOP}/linux/pyrope/tools/bin/nx_bingen -t 2ndboot -d ${option_d} -o ${secondboot_out_file} -i ${secondboot_file} -n ${nsih_file} -l 0x40100000 -e 0x40100000 ${option_p}
}

# example sequence
#WORKSPACE="/home/swpark/ws"
#BRANCH_NAME="kitkat-mr1-pyrope-dev"
#TOP="${WORKSPACE}/${BRANCH_NAME}"
#BUILD_TAG="swpark-my-test-build"
#RESULT_DIR="${TOP}/result"
#BOOT_DEVICE_TYPE="sd0"
#BOARD_NAME="drone"

##source packaging.sh
#get_root_device
#generate_partitionmap
#generate_2ndboot
#mkdir -p ${WORKSPACE}/${BUILD_TAG}/images
#cp ${RESULT_DIR}/partmap.txt ${WORKSPACE}/${BUILD_TAG}/images
#cp ${RESULT_DIR}/*.bin ${WORKSPACE}/${BUILD_TAG}/images
#cp ${RESULT_DIR}/*.img ${WORKSPACE}/${BUILD_TAG}/images
#cd ${WORKSPACE}/${BUILD_TAG}
#tar cvjf images.tar.bz2 images
#rm -rf images
#cd ${WORKSPACE}

#python /home/swpark/ws/jenkins-nexell-tool/linaro-cp.py -k 1234abcd --server 192.168.1.18:8080/ ${BUILD_TAG} android/${BUILD_TAG}
