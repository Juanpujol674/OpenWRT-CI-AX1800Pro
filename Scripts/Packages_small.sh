#!/usr/bin/env bash
set -e

# 作用：在 SMALL/SMAL 配置下，幂等地为 .config 追加常见 USB/串口/存储/网卡能力，避免过度精简导致 RNDIS/USB 无法识别。
# 使用：在工作流的 “Custom Packages(自定义软件包)” 步骤中执行本脚本。
# 注意：如果 .config 已启用对应项，本脚本不会重复写入。

ROOT_DIR="$(pwd)"
if [ -f "./feeds.conf" ] && [ -d "./package" ] && [ -d "./target" ]; then
  WRT_ROOT="$ROOT_DIR"
else
  # 若不在源码根目录，尝试回到 wrt 源码目录
  if [ -d "./wrt" ] && [ -f "./wrt/feeds.conf" ]; then
    WRT_ROOT="./wrt"
  else
    echo "[Packages_small] 未找到 OpenWrt 源码目录" >&2
    exit 0
  fi
fi

cd "$WRT_ROOT"

# 仅在 SMALL/SMAL 配置时启用
shopt -s nocasematch
if [[ "${WRT_CONFIG}" != *"SMALL"* && "${WRT_CONFIG}" != *"SMAL"* ]]; then
  echo "[Packages_small] 非 SMALL/SMAL 配置，跳过兜底追加"
  exit 0
fi
shopt -u nocasematch

CONFIG_FILE=".config"
touch "$CONFIG_FILE"

append_cfg () {
  local key="$1"
  if ! grep -qE "^${key}(=y|=m)$" "$CONFIG_FILE"; then
    echo "${key}=y" >> "$CONFIG_FILE"
  fi
}

# ===== USB Host 控制器 =====
append_cfg CONFIG_PACKAGE_kmod-usb-core
append_cfg CONFIG_PACKAGE_kmod-usb2
append_cfg CONFIG_PACKAGE_kmod-usb3
append_cfg CONFIG_PACKAGE_kmod-usb-ohci
append_cfg CONFIG_PACKAGE_kmod-usb-ehci
append_cfg CONFIG_PACKAGE_kmod-usb-ohci-pci
append_cfg CONFIG_PACKAGE_kmod-usb-ehci-pci
append_cfg CONFIG_PACKAGE_kmod-usb-xhci-hcd
append_cfg CONFIG_PACKAGE_kmod-usb-xhci-pci

# ===== USB 网络 =====
append_cfg CONFIG_PACKAGE_kmod-usb-net
append_cfg CONFIG_PACKAGE_kmod-usb-net-rndis
append_cfg CONFIG_PACKAGE_kmod-usb-net-cdc-ether
append_cfg CONFIG_PACKAGE_kmod-usb-net-cdc-ncm
append_cfg CONFIG_PACKAGE_kmod-usb-net-cdc-mbim
append_cfg CONFIG_PACKAGE_kmod-usb-net-asix
append_cfg CONFIG_PACKAGE_kmod-usb-net-asix-ax88179
append_cfg CONFIG_PACKAGE_kmod-usb-net-rtl8152

# ===== USB 串口 =====
append_cfg CONFIG_PACKAGE_kmod-usb-serial
append_cfg CONFIG_PACKAGE_kmod-usb-serial-ftdi
append_cfg CONFIG_PACKAGE_kmod-usb-serial-ch341
append_cfg CONFIG_PACKAGE_kmod-usb-serial-cp210x
append_cfg CONFIG_PACKAGE_kmod-usb-serial-option
append_cfg CONFIG_PACKAGE_kmod-usb-net-wwan

# ===== 存储与文件系统 =====
append_cfg CONFIG_PACKAGE_kmod-usb-storage
append_cfg CONFIG_PACKAGE_kmod-usb-storage-extras
append_cfg CONFIG_PACKAGE_kmod-usb-storage-uas
append_cfg CONFIG_PACKAGE_block-mount
append_cfg CONFIG_PACKAGE_e2fsprogs
append_cfg CONFIG_PACKAGE_kmod-fs-ext4
append_cfg CONFIG_PACKAGE_kmod-fs-vfat
append_cfg CONFIG_PACKAGE_kmod-fs-exfat
append_cfg CONFIG_PACKAGE_kmod-fs-ntfs

# ===== NLS 编码 =====
append_cfg CONFIG_PACKAGE_kmod-nls-base
append_cfg CONFIG_PACKAGE_kmod-nls-cp437
append_cfg CONFIG_PACKAGE_kmod-nls-iso8859-1
append_cfg CONFIG_PACKAGE_kmod-nls-utf8

# ===== 工具 =====
append_cfg CONFIG_PACKAGE_usbutils
append_cfg CONFIG_PACKAGE_usb-modeswitch

echo "[Packages_small] 已为 SMALL/SMAL 追加常用 USB/存储/串口/网卡能力"
