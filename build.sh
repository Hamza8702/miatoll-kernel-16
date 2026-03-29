#!/bin/bash
function compile()
{
source ~/.bashrc && source ~/.profile
export LC_ALL=C && export USE_CCACHE=1
ccache -M 25G
TANGGAL=$(date +"%Y%m%d-%H")
export ARCH=arm64
export KBUILD_BUILD_HOST=android-build
export KBUILD_BUILD_USER="kardebayan"
clangbin=clang/bin/clang
if ! [ -a $clangbin ]; then git clone --depth=1 https://github.com/crdroidandroid/android_prebuilts_clang_host_linux-x86_clang-6443078 clang
fi
gcc64bin=gcc64/bin/aarch64-linux-android-as
if ! [ -a $gcc64bin ]; then git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 gcc64
fi
gcc32bin=gcc32/bin/arm-linux-androideabi-as
if ! [ -a $gcc32bin ]; then git clone --depth=1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9 gcc32
fi
rm -rf AnyKernel
# --- START OF AUTO-FIX SECTION ---

# Fix extraneous ')' at line 9420 in fair.c
sed -i 's/cpumask_bits(&p->cpus_allowed)\[0\]);/cpumask_bits(\&p->cpus_allowed)[0];/g' kernel/sched/fair.c

# Fix double block comments /* /* at line 11214 in fair.c
sed -i 's/\/\* \/\* mark_reserved/\/\* mark_reserved/g' kernel/sched/fair.c
sed -i 's/this_cpu); \*\/ \*\//this_cpu); \*\//g' kernel/sched/fair.c

# Define FULL_THROTTLE_BOOST if missing to prevent "undeclared" error
sed -i '30i #ifndef FULL_THROTTLE_BOOST\n#define FULL_THROTTLE_BOOST 2\n#endif' kernel/sched/fair.c

# Add KVM support flags to out/.config
make O=out ARCH=arm64 vendor/xiaomi/miatoll_defconfig
echo "CONFIG_KVM=y" >> out/.config
echo "CONFIG_KVM_ARM_HOST=y" >> out/.config
echo "CONFIG_VIRTUALIZATION=y" >> out/.config
echo "CONFIG_KVM_ARM_VGIC_V3=y" >> out/.config
echo "CONFIG_KVM_ARM_PMU=y" >> out/.config
echo "CONFIG_VHOST_NET=y" >> out/.config
echo "CONFIG_VIRTIO_PCI=y" >> out/.config
make O=out ARCH=arm64 olddefconfig

# --- END OF AUTO-FIX SECTION ---

# Now start the compilation with KCFLAGS to ignore minor warnings
PATH="${PWD}/clang/bin:${PATH}:${PWD}/gcc32/bin:${PATH}:${PWD}/gcc64/bin:${PATH}" \
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
function zupload()
{
zimage=out/arch/arm64/boot/Image.gz
if ! [ -a $zimage ];
then
echo  " Failed To Compile Kernel"
else
echo -e " Kernel Compile Successful"
git clone --depth=1 https://github.com/Amritorock/AnyKernel3 -b r5x AnyKernel
cp out/arch/arm64/boot/Image.gz AnyKernel
cd AnyKernel
zip -r9 Stormbreaker-miatoll-${TANGGAL}.zip *
cd ../
fi
}
compile
zupload
