#!/bin/bash

# --- KERNEL COMPILATION FUNCTION ---
function compile()
{
    # Setup build environment
    source ~/.bashrc && source ~/.profile
    export LC_ALL=C && export USE_CCACHE=1
    ccache -M 25G
    TIMESTAMP=$(date +"%Y%m%d-%H")
    
    # Architecture and build identity
    export ARCH=arm64
    export KBUILD_BUILD_HOST=android-build
    export KBUILD_BUILD_USER="kardebayan"

    # 1. Download Tools (Clang & GCC)
    # Using check to skip if already present
    [ ! -d "clang" ] && git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6443078 clang
    [ ! -d "gcc64" ] && git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc64
    [ ! -d "gcc32" ] && git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32

    # 2. Kernel Configuration
    make O=out ARCH=arm64 vendor/xiaomi/miatoll_defconfig
    # --- EMERGENCY TOUCHSCREEN FIRMWARE FIX ---
# Create the directory where the compiler is looking
mkdir -p include/firmware

# Copy the file from driver source to the expected location
cp drivers/input/touchscreen/ft8756_spi/include/firmware/fw_huaxing_v0e.i include/firmware/

# Also copy to the 'out' directory for double safety
mkdir -p out/include/firmware
cp drivers/input/touchscreen/ft8756_spi/include/firmware/fw_huaxing_v0e.i out/include/firmware/

echo "Success: Firmware files linked and ready for compilation."

    # Virtualization / KVM Support
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

    # 3. Main Build Process
    # PATH includes compilers; KCFLAGS used to bypass minor warnings
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
        echo " BUILD STATUS: FAILED "
        echo "--------------------------------------"
    else
        echo "--------------------------------------"
        echo " BUILD STATUS: SUCCESSFUL! "
        echo "--------------------------------------"
        
        # Zip the kernel with AnyKernel3
        rm -rf AnyKernel
        git clone --depth=1 https://github.com/Amritorock/AnyKernel3 -b r5x AnyKernel
        cp out/arch/arm64/boot/Image.gz AnyKernel/
        
        cd AnyKernel
        zip -r9 "Stormbreaker-miatoll-${TIMESTAMP}.zip" *
        cd ..
        echo "Artifact: Stormbreaker-miatoll-${TIMESTAMP}.zip"
    fi
}

compile
zupload
