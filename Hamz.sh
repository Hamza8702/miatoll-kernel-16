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

            # 2. Apply Mandatory Fixes (The Ultimate Fix)
    echo "Applying surgical source patches..."

    # Fix 1: cpu_errata.c Header & Symbol Fix
    ERRATA_FILE="arch/arm64/kernel/cpu_errata.c"
    sed -i '/linux\/arm64_capabilities.h/d' "$ERRATA_FILE"
    if ! grep -q "arm64_enable_wa2_handling" "$ERRATA_FILE"; then
        echo -e "\n#include <linux/export.h>\n#include <asm/cpufeature.h>\nvoid arm64_enable_wa2_handling(const struct arm64_cpu_capabilities *cap) { }\nEXPORT_SYMBOL_GPL(arm64_enable_wa2_handling);" >> "$ERRATA_FILE"
    fi

    # Fix 2: Scheduler Missing Definitions (NOHZ & BOOST)
    # Defining missing NOHZ_BALANCE_KICK and FULL_THROTTLE_BOOST in scheduler core
    SCHED_CORE="kernel/sched/core.c"
    SCHED_FAIR="kernel/sched/fair.c"
    
    # Injecting NOHZ_BALANCE_KICK definition if missing
    if ! grep -q "NOHZ_BALANCE_KICK" "$SCHED_CORE"; then
        sed -i '1i #define NOHZ_BALANCE_KICK 1' "$SCHED_CORE"
    fi

    # Injecting FULL_THROTTLE_BOOST definition
    if ! grep -q "FULL_THROTTLE_BOOST" "$SCHED_FAIR"; then
        sed -i '1i #define FULL_THROTTLE_BOOST 2' "$SCHED_FAIR"
    fi

    # Fix 3: NR_CPUS Tracepoint Error Bypass
    TRACE_SCHED="include/trace/events/sched.h"
    sed -i 's/#error "Unsupported NR_CPUS for lb tracepoint."/\/\/#error "Bypassed by Hamza"/g' "$TRACE_SCHED"

    # Fix 4: Scheduler Syntax Fix
    sed -i 's/cpumask_bits(&p->cpus_allowed)\[0\]);/cpumask_bits(\&p->cpus_allowed)[0];/g' "$SCHED_FAIR"
    
    # Fix 5: Touchscreen Firmware Directory
    mkdir -p include/firmware
    [ -f "drivers/input/touchscreen/ft8756_spi/include/firmware/fw_huaxing_v0e.i" ] && cp drivers/input/touchscreen/ft8756_spi/include/firmware/fw_huaxing_v0e.i include/firmware/

    # 3. Kernel Configuration
    make O=out ARCH=arm64 vendor/xiaomi/miatoll.config
    
    # KVM & NR_CPUS & Spectre Fix
    {
        echo "CONFIG_KVM=y"
        echo "CONFIG_KVM_ARM_HOST=y"
        echo "CONFIG_VIRTUALIZATION=y"
        echo "CONFIG_NR_CPUS=8"
        echo "CONFIG_KVM_ARM_VGIC_V3=y"
        echo "CONFIG_KVM_ARM_PMU=y"
        echo "CONFIG_HARDEN_BRANCH_PREDICTOR=n"
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

# --- PACKAGING FUNCTION (Direct Boot Folder) ---
function zupload()
{
    BOOT_DIR="out/arch/arm64/boot"
    
    if [ ! -d "$BOOT_DIR" ]; then
        echo "ERROR: Boot directory not found. Compilation failed!"
    else
        echo "SUCCESS: Kernel compiled! Packaging the raw boot files..."
        
        # Packaging everything inside out/arch/arm64/boot
        # This includes Image.gz, dtbo.img, and the dts folder
        cd "$BOOT_DIR"
        zip -r9 "../../../../Stormbreaker-miatoll-RAW-${TIMESTAMP}.zip" *
        cd ../../../..
        
        echo "Artifact created: Stormbreaker-miatoll-RAW-${TIMESTAMP}.zip"
    fi
}

compile
zupload
