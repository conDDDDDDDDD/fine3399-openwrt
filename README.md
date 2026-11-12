# Fine3399 OpenWrt 路由器固件

为 **Rumu3f Fine3399**（bozztek SW799 核心板，RK3399 / 4GB LPDDR4 / 8GB eMMC）定制的 OpenWrt 固件构建仓库。

- 基线：**OpenWrt 24.10**（kernel 6.6 + U-Boot 2024.10）
- 形态：纯有线路由（双千兆），WiFi / 蓝牙 / HDMI / SPI 小屏默认关闭
- 编译：GitHub Actions 云编译，产物为可刷写的 `sysupgrade.img.gz`

## 目录结构

```
board/
  device.mk                  # 追加到 target/linux/rockchip/image/armv8.mk 的设备定义
  kernel.config              # 追加到 rockchip/armv8/config-6.6 的内核选项
  kernel/
    rk3399-fine3399.dts      # 内核设备树（源自 Armbian，已改为路由用途）
    Makefile.patch           # 把 dtb 注册进内核 Makefile
  uboot/
    fine3399-rk3399_defconfig
    rk3399-fine3399.dts
    rk3399-fine3399-u-boot.dtsi
  uboot.mk                   # U-Boot 变体 + UBOOT_TARGETS 注册
configs/
  fine3399.config            # OpenWrt .config 种子
files/                       # 打包进 rootfs 的覆盖文件
  etc/board.d/99_fine3399    # WAN/LAN 口序 + 由 eMMC CID 生成固定 MAC
  etc/uci-defaults/99-fine3399-system
scripts/
  apply.sh                   # 把上述内容注入干净的 OpenWrt 源码树
  mkpatch.py                 # 生成 new-file 补丁
.github/workflows/build.yml  # 云编译流程
```

## 口序与默认网络

| 接口 | 硬件 | OpenWrt 角色 | 默认 |
|---|---|---|---|
| `eth0` | RK3399 GMAC + RTL8211（原生 RGMII） | **WAN** | DHCP |
| `eth1` | RTL8153B（USB 3.0 转千兆） | **LAN** | `192.168.1.1/24` |

- 首次启动后：LAN 口接电脑，浏览器打开 `http://192.168.1.1`，无密码。
- 想反过来用，改 `files/etc/board.d/99_fine3399` 里的
  `ucidef_set_interfaces_lan_wan 'eth1' 'eth0'` 即可。
- 调试串口：**UART2，1500000 8N1**（USB-TTL 必须支持 1.5M 波特率）。

## 使用 GitHub Actions 编译

本机不需要装编译环境，全部在 GitHub 上完成。

### 1. 新建仓库

在 GitHub 新建一个空仓库（不要勾选 README / .gitignore），例如 `fine3399-openwrt`。

### 2. 推送本目录

```sh
cd ~/fine3399/build
git init -b main
git add .
git commit -m "Fine3399 OpenWrt build"
git remote add origin git@github.com:<你的用户名>/fine3399-openwrt.git
git push -u origin main
```

### 3. 触发编译

- 推送到 `main` 会自动触发；
- 也可以在 **Actions → Build Fine3399 OpenWrt → Run workflow** 手动触发，
  并可填写要编译的 OpenWrt tag（默认 `v24.10.8`）。

4 核 runner 大约需要 2–3 小时。产物在 workflow 页面的 **Artifacts** 里：

```
openwrt-24.10.8-rockchip-armv8-rumu3f_fine3399-squashfs-sysupgrade.img.gz
```

## 本地编译（可选）

```sh
git clone --depth 1 -b v24.10.8 https://github.com/openwrt/openwrt.git openwrt
./scripts/apply.sh openwrt
cp configs/fine3399.config openwrt/.config
cd openwrt
make defconfig
make download -j8
make -j8
```

## 刷机

### 先刷 TF 卡验证（强烈建议）

```sh
# Linux，确认 /dev/sdX 是 TF 卡，别写错盘
gzip -dc openwrt-*-rumu3f_fine3399-squashfs-sysupgrade.img.gz | sudo dd of=/dev/sdX bs=4M conv=fsync status=progress
```

把 TF 卡插到底板，接串口（1.5M），上电。U-Boot 会优先从 TF 启动。

### 写入 eMMC

确认 TF 版一切正常后，在设备上把镜像写到 eMMC（RK3399 上 eMMC 通常是 `/dev/mmcblk2`）：

```sh
# 在设备上执行，镜像先放到 /tmp
lsblk                       # 确认 eMMC 的块设备名
gzip -dc /tmp/fine3399.img.gz | dd of=/dev/mmcblk2 bs=4M conv=fsync
sync && reboot
```

> 注意：`dd` 会覆盖 eMMC 上的所有内容。写入前请确认设备名。

### 救砖

- 优先用 TF 卡启动救回；
- 无法启动时，短接核心板上的 eMMC 触点进入 Maskrom，用 `rkdeveloptool` 或瑞芯微刷机工具重写。

## 已做的主要改动

**内核设备树**（`board/kernel/rk3399-fine3399.dts`）

- 移植自 Armbian `rk3399-fine3399.dts`，保留 RK808 PMIC、SYR827/828、GMAC、
  eMMC HS400、TF、USB3、PCIe（NVMe）、PWM 风扇、电源键、Recovery ADC 键；
- 额外引入 `rk3399-opp.dtsi`，让 `cpufreq-dt` 正常工作；
- 关闭：AP6236 WiFi（`sdio0`）、蓝牙（`uart0`）、HDMI/VOP、SPI ST7735S 小屏、
  背光、IR 接收、GPU。

**内核选项**（`board/kernel.config`）

- `CONFIG_ROCKCHIP_SARADC=y`（Recovery 键）
- `CONFIG_KEYBOARD_ADC=y`（adc-keys）
- SYR827/SYR828 供电走 `CONFIG_REGULATOR_FAN53555`（rockchip 目标默认已开）

**U-Boot**

- 以 Armbian 的 `fine3399-rk3399_defconfig` 为基础，改用 U-Boot 2024.10 的
  `dts/upstream` 路径（`CONFIG_DEFAULT_DEVICE_TREE="rockchip/rk3399-fine3399"`）；
- 补齐 `SPL_MAX_SIZE` / `SPL_PAD_TO` / `SPL_ATF_NO_PLATFORM_PARAM` /
  `MMC_SDHCI_SDMA` / `PHY_REALTEK` 等 OpenWrt 侧常用选项；
- LPDDR4 通过 `CONFIG_RAM_RK3399_LPDDR4=y` 和 `rk3399-sdram-lpddr4-100.dtsi` 指定。

## 已知限制

- 首版不启用 WiFi/BT：AP6236 需要额外 nvram 与固件，且 2.4G 单频不适合做主路由。
- USB 网口枚举顺序理论上有波动；当前按 `eth0`=原生、`eth1`=USB 分配。
  如果你的板子相反，按上面的方法交换即可。
- 根分区固定 2GB，8GB eMMC 剩余空间未分区，后续可自行建数据分区。
- GitHub Actions 的 runner 磁盘较紧，workflow 里已做清理；若仍失败，可改用
  self-hosted runner 或本地编译。
