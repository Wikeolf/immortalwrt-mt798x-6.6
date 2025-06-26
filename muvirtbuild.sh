#!/bin/bash
set -e

# Print usage information
usage() {
    echo "Usage: $0 <defConfig> [<target>]"
    echo "Example: $0 muvirt_defconfig TARGET_mediatek_filogic"
    echo "Available defConfigs:"
    ls defconfig/ | grep muvirt
}

# Check if the script is run with at least one argument
if [ $# -lt 1 ]; then
    usage
    exit 1
fi

# Get the configuration file from the first argument
CONF=$1
# Get Target Architecture
TARGET=${2:-TARGET_mediatek_filogic}


./scripts/feeds update -a
./scripts/feeds install -a

# add muvirt feeds
echo "Adding muvirt feeds..."
cat > feeds.conf <<EOF
src-git muvirt https://gitlab.com/traversetech/muvirt-feed.git
src-git ten64 https://gitlab.com/traversetech/ls1088firmware/ten64-openwrt-feed.git
src-git openwisp https://github.com/openwisp/openwisp-config.git
src-git notengobattery https://github.com/NoTengoBattery/openwrt-custom-feed.git
EOF

# update and install feeds and patch qemu deps
echo "Updating and installing feeds..."
./scripts/feeds update -a
./scripts/feeds install -p muvirt -a 
./scripts/feeds install tpm-tools
./scripts/feeds install trousers
./scripts/feeds install luci-app-compressed-memory
./scripts/feeds install compressed-memory
./scripts/feeds install -p openwisp openwisp-config

echo "Patching qemu dependencies..."
sed package/feeds/packages/qemu/Makefile -i \
    -e 's/QEMU_DEPS_IN_GUEST := @(TARGET_x86||TARGET_x86_64||TARGET_armsr||TARGET_malta)/QEMU_DEPS_IN_GUEST := @(TARGET_x86||TARGET_x86_64||TARGET_armsr||TARGET_malta||'"${TARGET}"')/g' \
    -e 's/QEMU_DEPS_IN_HOST := @(TARGET_x86_64||TARGET_armsr_armv8||TARGET_sunxi)/QEMU_DEPS_IN_HOST := @(TARGET_x86_64||TARGET_armsr_armv8||TARGET_sunxi||'"${TARGET}"')/g'

# apply default configuration
echo "Applying default configuration..."
cp defconfig/${CONF} .config
make defconfig

# check dependencies in .config
grep "CONFIG_PACKAGE_muvirt=y" .config || (echo "muvirt not selected" && exit 1)
grep "CONFIG_PACKAGE_luci=y" .config || (echo "LuCI not selected" && exit 1)
grep "CONFIG_PACKAGE_lvm2=y" .config || (echo "LVM not selected" && exit 1)
grep "CONFIG_PACKAGE_tmux=y" .config || (echo "tmux not selected" && exit 1)
grep "CONFIG_PACKAGE_qemu-img" .config || (echo "qemu-img not selected" && exit 1)
grep "CONFIG_PACKAGE_qemu-nbd" .config || (echo "qemu-nbd not selected" && exit 1)
grep "CONFIG_PACKAGE_ethtool-full=y" .config || (echo "ethtool-full not selected" && exit 1)
grep "CONFIG_PACKAGE_luci-proto-wireguard=y" .config || (echo "luci-proto-wireguard not selected" && exit 1)
grep "CONFIG_PACKAGE_qrencode=y" .config || (echo "qrencode not selected" && exit 1)

echo "Now you can select additional packages with 'make menuconfig'"
echo "and then build with 'make -j$(nproc)'"