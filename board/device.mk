
define Device/rumu3f_fine3399
  DEVICE_VENDOR := Rumu3f
  DEVICE_MODEL := Fine3399
  DEVICE_VARIANT := RK3399 4GB
  SOC := rk3399
  DEVICE_DTS := rockchip/rk3399-fine3399
  UBOOT_DEVICE_NAME := fine3399-rk3399
  SUPPORTED_DEVICES := rockchip,fine3399 rumu3f,fine3399
  DEVICE_PACKAGES := \
    kmod-usb-net-rtl8152 \
    kmod-nvme \
    kmod-usb-storage \
    kmod-fs-ext4 \
    kmod-fs-vfat \
    block-mount \
    blkdiscard \
    kmod-hwmon-pwmfan \
    kmod-input-gpio-keys \
    ethtool \
    irqbalance
endef
TARGET_DEVICES += rumu3f_fine3399
