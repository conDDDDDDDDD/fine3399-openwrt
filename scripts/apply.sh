#!/bin/sh
#
# Inject Fine3399 support into a clean OpenWrt checkout.
#
#   ./scripts/apply.sh /path/to/openwrt
#
set -eu

ROOT=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
OW=${1:-"$ROOT/openwrt"}

if [ ! -d "$OW/target/linux/rockchip" ]; then
	echo "error: $OW does not look like an OpenWrt tree" >&2
	exit 1
fi

echo "==> device definition"
cat "$ROOT/board/device.mk" >> "$OW/target/linux/rockchip/image/armv8.mk"

echo "==> kernel device tree patch"
mkdir -p "$OW/target/linux/rockchip/patches-6.6"
python3 "$ROOT/scripts/mkpatch.py" --base "$ROOT/board" \
	--out "$OW/target/linux/rockchip/patches-6.6/999-add-fine3399.patch" \
	"kernel/rk3399-fine3399.dts:arch/arm64/boot/dts/rockchip/rk3399-fine3399.dts"
cp "$ROOT/board/kernel/Makefile.patch" \
	"$OW/target/linux/rockchip/patches-6.6/998-fine3399-dtb.patch"

echo "==> kernel config"
sed -i 's/^# CONFIG_ROCKCHIP_SARADC is not set$/CONFIG_ROCKCHIP_SARADC=y/' \
	"$OW/target/linux/rockchip/armv8/config-6.6"
cat "$ROOT/board/kernel.config" >> "$OW/target/linux/rockchip/armv8/config-6.6"

echo "==> u-boot sources"
mkdir -p "$OW/package/boot/uboot-rockchip/patches"
python3 "$ROOT/scripts/mkpatch.py" --base "$ROOT/board" \
	--out "$OW/package/boot/uboot-rockchip/patches/999-add-fine3399.patch" \
	"uboot/fine3399-rk3399_defconfig:configs/fine3399-rk3399_defconfig" \
	"uboot/rk3399-fine3399.dts:dts/upstream/src/arm64/rockchip/rk3399-fine3399.dts" \
	"uboot/rk3399-fine3399-u-boot.dtsi:arch/arm/dts/rk3399-fine3399-u-boot.dtsi"

echo "==> u-boot package variant"
python3 - "$OW/package/boot/uboot-rockchip/Makefile" "$ROOT/board/uboot.mk" <<'PY'
import sys

mk, add = sys.argv[1], sys.argv[2]
with open(mk, encoding="utf-8") as f:
    text = f.read()
with open(add, encoding="utf-8") as f:
    block = f.read().strip("\n")

marker = "UBOOT_TARGETS := \\\n"
if marker not in text:
    raise SystemExit("UBOOT_TARGETS not found in %s" % mk)

text = text.replace(marker, block + "\n\n" + marker, 1)
text = text.replace(marker, marker + "  fine3399-rk3399 \\\n", 1)

with open(mk, "w", encoding="utf-8") as f:
    f.write(text)
PY

echo "==> rootfs overlay"
mkdir -p "$OW/files"
cp -a "$ROOT/files/." "$OW/files/"

echo
echo "Fine3399 support applied to $OW"
echo "Next: cp configs/fine3399.config .config && make defconfig"
