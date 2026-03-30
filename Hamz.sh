#!/bin/bash

# --- KERNEL COMPILATION FUNCTION ---
function compile()
{
    source ~/.bashrc && source ~/.profile
    export LC_ALL=C && export USE_CCACHE=1
    ccache -M 25G
    TIMESTAMP=$(date +"%Y%m%d-%H")
    export ARCH=arm64
    export KBUILD_BUILD_HOST=android-build
    export KBUILD_BUILD_USER="kardebayan"

    # 1. Download Toolchains
    [ ! -d "clang" ] && git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6443078 clang
    [ ! -d "gcc64" ] && git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc64
    [ ! -d "gcc32" ] && git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32

    # 2. Apply Mandatory Fixes (The Final Polish)
    echo "Applying final source patches..."
    # Touchscreen Firmware Fix
    mkdir -p include/firmware
    cp drivers/input/touchscreen/ft8756_spi/include/firmware/fw_huaxing_v0e.i include/firmware/
    sed -i 's|#define FTS_UPGRADE_FW_FILE.*|#define FTS_UPGRADE_FW_FILE "include/firmware/fw_huaxing_v0e.i"|g' drivers/input/touchscreen/ft8756_spi/focaltech_config.h
    
    # Scheduler Fix
    sed -i '9420s/cpumask_bits(&p->cpus_allowed)\[0\]);/cpumask_bits(\&p->cpus_allowed)[0];/g' kernel/sched/fair.c
    sed -i '11214c\        /* mark_reserved(this_cpu); */' kernel/sched/fair.c

    # 3. Kernel Configuration
    make O=out ARCH=arm64 vendor/xiaomi/miatoll.config
    
    # KVM / Virtualization
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

    # 4. Final Build Attempt
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
        echo "ERROR: Kernel binary not found. Compilation failed at the final stage."
    else
        echo "SUCCESS: Kernel compiled! Creating flashable zip..."
        rm -rf AnyKernel
        git clone --depth=1 https://github.com/Amritorock/AnyKernel3 -b r5x AnyKernel
        cp out/arch/arm64/boot/Image.gz AnyKernel/
        cd AnyKernel
        zip -r9 "Stormbreaker-miatoll-${TIMESTAMP}.zip" *
        cd ..
    fi
}

compile
zupload
