#!/bin/bash

# --- KERNEL COMPILATION FUNCTION ---
function compile()
{
    # Environment Setup
    source ~/.bashrc && source ~/.profile
    export LC_ALL=C && export USE_CCACHE=1
    ccache -M 25G
    TIMESTAMP=$(date +"%Y%m%d-%H")
    
    # Architecture and Identity
    export ARCH=arm64
    export KBUILD_BUILD_HOST=android-build
    export KBUILD_BUILD_USER="kardebayan"

    # 1. Prepare Tools (Clang & GCC)
    if [ ! -d "clang" ]; then
        git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6443078 clang
    fi
    if [ ! -d "gcc64" ]; then
        git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc64
    fi
    if [ ! -d "gcc32" ]; then
        git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32
    fi

    # 2. Hardcoded Fixes (Applying patches before config)
    echo "Applying hardcoded patches..."

    # Fix Touchscreen Firmware Path
    # Redirecting include path directly to the driver source
    sed -i 's|"include/firmware/fw_huaxing_v0e.i"|"../drivers/input/touchscreen/ft8756_spi/include/firmware/fw_huaxing_v0e.i"|g' drivers/input/touchscreen/ft8756_spi/focaltech_config.h

    # Fix Scheduler Syntax Errors (fair.c)
    # Removing extra parenthesis at line 9420 and fixing comments at 11214
    sed -i '9420s/cpumask_bits(&p->cpus_allowed)\[0\]);/cpumask_bits(\&p->cpus_allowed)[0];/g' kernel/sched/fair.c
    sed -i '11214c\        /* mark_reserved(this_cpu); */' kernel/sched/fair.c

    # 3. Kernel Configuration
    make O=out ARCH=arm64 vendor/xiaomi/miatoll_defconfig
    
    # Injecting KVM Support
    {
        echo "CONFIG_KVM=y"
        echo "CONFIG_KVM_ARM_HOST=y"
        echo "CONFIG_VIRTUALIZATION=y"
        echo "CONFIG_KVM_ARM_VGIC_V3=y"
        echo "CONFIG_KVM_ARM_PMU=y"
        echo "CONFIG_VHOST_NET=y"
        echo "CONFIG_VIRTIO_PCI=y"
    } >> out/.config
    
    make O=out ARCH=arm64 olddefconfig

    # 4. Start Compilation
    PATH="${PWD}/clang/bin:${PWD}/gcc64/bin:${PWD}/gcc32/bin:${PATH}" \
    make -j$(nproc --all) O=out \
                          ARCH=arm64 \
                          CC="clang" \
                          CLANG_TRIPLE=aarch64-linux-gnu- \
                          CROSS_COMPILE="${PWD}/gcc64/bin/aarch64-linux-android-" \
                          CROSS_COMPILE_ARM32="${PWD}/gcc32/bin/arm-linux-androideabi-" \
                          LD=ld.lld \
                          CONFIG_NO_ERROR_ON_MISMATCH=y \
                          KCFLAGS="-Wno-error -Wno-implicit-function-declaration -Wno-declaration-after-statement"
}

# --- PACKAGING FUNCTION ---
function zupload()
{
    IMAGE=out/arch/arm64/boot/Image.gz
    if [ ! -f "$IMAGE" ]; then
        echo "--------------------------------------"
        echo " STATUS: Compilation Failed "
        echo "--------------------------------------"
    else
        echo "--------------------------------------"
        echo " STATUS: Success! Packaging Started "
        echo "--------------------------------------"
        
        rm -rf AnyKernel
        git clone --depth=1 https://github.com/Amritorock/AnyKernel3 -b r5x AnyKernel
        cp out/arch/arm64/boot/Image.gz AnyKernel/
        
        cd AnyKernel
        zip -r9 "Stormbreaker-miatoll-${TIMESTAMP}.zip" *
        cd ..
        echo "Build Package: Stormbreaker-miatoll-${TIMESTAMP}.zip"
    fi
}

compile
zupload
