#!/bin/bash

# --- KERNEL COMPILATION FUNCTION ---
function compile()
{
    # Setup environment
    source ~/.bashrc && source ~/.profile
    export LC_ALL=C && export USE_CCACHE=1
    ccache -M 25G
    TIMESTAMP=$(date +"%Y%m%d-%H")
    
    # Target Architecture and User Info
    export ARCH=arm64
    export KBUILD_BUILD_HOST=android-build
    export KBUILD_BUILD_USER="kardebayan"

    # Clone Compiler Tools (Clang & GCC) if they don't exist
    if [ ! -d "clang" ]; then
        git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6443078 clang
    fi
    if [ ! -d "gcc64" ]; then
        git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc64
    fi
    if [ ! -d "gcc32" ]; then
        git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32
    fi

    # Initialize Kernel Configuration
    # --- FORCE PATCHING SCHEDULER (fair.c) ---
# 9420. satırdaki hatalı parantezi kaldır
sed -i '9420s/cpumask_bits(&p->cpus_allowed)\[0\]);/cpumask_bits(\&p->cpus_allowed)[0];/g' kernel/sched/fair.c

# 11214. satırdaki iç içe geçmiş yorumları (/* /*) temizle
sed -i '11214s/\/\* \/\* mark_reserved(this_cpu); \*\/ \*\//\/\* mark_reserved(this_cpu); \*\//g' kernel/sched/fair.c

echo "Success: Scheduler forced patches applied."

    make O=out ARCH=arm64 vendor/xiaomi/miatoll_defconfig
    
    # Inject Virtualization Support (KVM)
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

    # START COMPILATION
    # Note: Source code was manually patched in Chroot, no extra sed/cp needed here.
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

# --- UPLOAD AND PACKAGE FUNCTION ---
function zupload()
{
    IMAGE=out/arch/arm64/boot/Image.gz
    if [ ! -f "$IMAGE" ]; then
        echo "--------------------------------------"
        echo " ERROR: Kernel Compilation Failed! "
        echo "--------------------------------------"
    else
        echo "--------------------------------------"
        echo " SUCCESS: Kernel Compiled Successfully! "
        echo "--------------------------------------"
        
        # Prepare AnyKernel3 for flashing
        rm -rf AnyKernel
        git clone --depth=1 https://github.com/Amritorock/AnyKernel3 -b r5x AnyKernel
        cp out/arch/arm64/boot/Image.gz AnyKernel/
        
        # Create Final Zip
        cd AnyKernel
        zip -r9 "Stormbreaker-miatoll-${TIMESTAMP}.zip" *
        cd ..
        echo "Package Ready: Stormbreaker-miatoll-${TIMESTAMP}.zip"
    fi
}

# Execute
compile
zupload
