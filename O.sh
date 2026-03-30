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

    make O=out ARCH=arm64 vendor/xiaomi/miatoll.config
    
    # KVM & NR_CPUS & Fixes
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
