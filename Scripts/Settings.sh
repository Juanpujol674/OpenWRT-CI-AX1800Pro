#!/usr/bin/env bash
set -e

# =========================================================
#  基础系统项：网段/IP 与主机名
# =========================================================
CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

# =========================================================
#  基础 LuCI 与主题
# =========================================================
{
  echo "CONFIG_PACKAGE_luci=y"
  echo "CONFIG_LUCI_LANG_zh_Hans=y"
  echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y"
  echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y"
  echo "CONFIG_PACKAGE_luci-theme-bootstrap=y"
} >> ./.config

# 手动附加（来自 workflow 传入）
if [ -n "$WRT_PACKAGE" ]; then
  echo -e "$WRT_PACKAGE" >> ./.config
fi

# =========================================================
#  高通/Qualcomm NSS 固件选择与 nowifi 处理
# =========================================================
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
  echo "CONFIG_FEED_nss_packages=n" >> ./.config
  echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
  echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
  echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config

  echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
  if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
  else
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
  fi

  # WIFI-NO: 切换到 nowifi dtsi
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec \
      sed -i 's/ipq\(6018\|8074\)\.dtsi/ipq\1-nowifi.dtsi/g' {} +
    echo "qualcommax set up nowifi successfully!"
  fi
fi

# =========================================================
#  dropbear 配置修正
# =========================================================
sed -i "s/Interface/DirectInterface/" \
  ./package/network/services/dropbear/files/dropbear.config || true

# =========================================================
#  不建议拉入的包（保持稳态）
# =========================================================
cat >> ./.config <<'EOF_BLOCK_BAD'
CONFIG_PACKAGE_luci-app-advancedplus=n
CONFIG_PACKAGE_luci-theme-kucat=n
# feeds 可能带入的代理相关（容易引错）
CONFIG_PACKAGE_dae=n
CONFIG_PACKAGE_daed=n
CONFIG_PACKAGE_luci-app-v2raya=n
CONFIG_PACKAGE_v2raya=n
EOF_BLOCK_BAD

# =========================================================
#  常用工具 / 应用（默认启用，SMALL 会在后面再做微调）
# =========================================================
cat >> ./.config <<'EOF_TOOLS'
CONFIG_CGROUPS=y
CONFIG_CPUSETS=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_coreutils-base64=y
CONFIG_PACKAGE_coreutils=y
CONFIG_PACKAGE_btop=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_tcping=y
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_git-http=y
CONFIG_PACKAGE_zoneinfo-asia=y
CONFIG_PACKAGE_bind-dig=y
CONFIG_PACKAGE_ss=y

# LuCI 应用（非 SMALL 后面 Podman 会加强）
CONFIG_PACKAGE_luci-app-openlist2=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_lucky=y
CONFIG_PACKAGE_luci-app-caddy=y
CONFIG_PACKAGE_luci-app-filemanager=y
CONFIG_PACKAGE_luci-app-gost=y
CONFIG_PACKAGE_luci-app-nginx=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_luci-app-turboacc=y
# 让发布页显示：
CONFIG_PACKAGE_luci-app-package-manager=y

# Tailscale（大小内存都启用，满足你的新需求）
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
EOF_TOOLS

# =========================================================
#  SMALL 体积保护 + 白名单
# =========================================================
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected, applying minimal/safe package set"

    # small 也按你的要求启用 momo/nikki 与 sing-box
    cat >> ./.config << 'EOF_SM_MIN'
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_lucky=y
EOF_SM_MIN

    # SMALL 保留的一些常见 LuCI
    cat >> ./.config << 'EOF_SM_WHITE'
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y


# SMALL 也启用 tailscale filemanager luck
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
CONFIG_PACKAGE_luci-app-filemanager=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_lucky=y
EOF_SM_WHITE

    # SMALL 禁掉超大依赖的组件（Podman/Docker/下载器等）
    cat >> ./.config << 'EOF_SM_BLOCK'
CONFIG_PACKAGE_luci-app-openclash=n
CONFIG_PACKAGE_openclash=n
#CONFIG_PACKAGE_luci-app-lucky=n
#CONFIG_PACKAGE_lucky=n
CONFIG_PACKAGE_luci-app-dockerman=n
CONFIG_PACKAGE_dockerd=n
CONFIG_PACKAGE_containerd=n
CONFIG_PACKAGE_luci-app-podman=n
CONFIG_PACKAGE_podman=n
CONFIG_PACKAGE_luci-app-qbittorrent=n
CONFIG_PACKAGE_qbittorrent=n
CONFIG_PACKAGE_luci-app-gost=n
CONFIG_PACKAGE_gost=n
CONFIG_PACKAGE_luci-app-nginx=n
CONFIG_PACKAGE_nginx-mod-luci=n
#CONFIG_PACKAGE_luci-app-filemanager=n
CONFIG_PACKAGE_btop=n
CONFIG_PACKAGE_bind-dig=n
CONFIG_PACKAGE_coreutils=n
CONFIG_PACKAGE_coreutils-base64=n
EOF_SM_BLOCK

    # 若 feeds 中没有 sing-box，则关闭，避免失败
    if ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d package/sing-box ]; then
      echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
      echo ">> WARNING: sing-box package not found, disabled to avoid build failure."
    fi
  ;;
esac

# =========================================================
#  大闪存机型：避免 SQM CONTROL 冲突
# =========================================================
case "${WRT_CONFIG,,}" in
  *wifi-yes*|*wifi-no*)
    echo ">> Disable sqm-scripts-nss to prevent CONTROL conflict"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=n" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts=y" >> ./.config
    ;;
esac

# =========================================================
#  Podman 运行最优配置（仅非 SMALL 启用）
# =========================================================
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL build: skip heavy Podman stack auto-enable"
    ;;
  *)
    echo ">> Enable full Podman stack (packages + kernel features)"

    # 运行时工具与依赖
    cat >> ./.config << 'EOF_POD_PKGS'
CONFIG_PACKAGE_luci-app-podman=y
CONFIG_PACKAGE_podman=y
CONFIG_PACKAGE_conmon=y
CONFIG_PACKAGE_crun=y
CONFIG_PACKAGE_catatonit=y
CONFIG_PACKAGE_slirp4netns=y
CONFIG_PACKAGE_fuse-overlayfs=y
CONFIG_PACKAGE_uidmap=y
CONFIG_PACKAGE_netavark=y
CONFIG_PACKAGE_aardvark-dns=y
CONFIG_PACKAGE_containers-storage=y
CONFIG_PACKAGE_podman-compose=y
EOF_POD_PKGS

    # 内核特性
    cat >> ./.config << 'EOF_POD_KCFG'
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_PIDS=y
CONFIG_KERNEL_MEMCG=y
CONFIG_KERNEL_NAMESPACES=y
CONFIG_KERNEL_USER_NS=y
CONFIG_KERNEL_SECCOMP=y
CONFIG_KERNEL_SECCOMP_FILTER=y
CONFIG_KERNEL_KEYS=y
EOF_POD_KCFG

    # 运行时默认参数（sysctl）
    mkdir -p ./files/etc/sysctl.d
    cat > ./files/etc/sysctl.d/99-podman.conf << 'EOF_SYSCTL'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF_SYSCTL
    ;;
esac

# =========================================================
#  非 SMALL：也显式开启 momo / nikki（与 SMALL 一致保持开启）
# =========================================================
echo "CONFIG_PACKAGE_luci-app-momo=y"  >> ./.config
echo "CONFIG_PACKAGE_luci-app-nikki=y" >> ./.config

# =========================================================
#  方案 B（推荐）：USB/RNDIS/CDC/网卡/串口/存储/文件系统 一次性启用
#  —— 大小内存版都启用，放在靠后，避免被前面 =n 覆盖
# =========================================================
cat >> ./.config <<'EOF_USB_ALL'
# USB Host 控制器
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-ohci=y
CONFIG_PACKAGE_kmod-usb-ehci=y
CONFIG_PACKAGE_kmod-usb-xhci-hcd=y

# 常见 USB 网卡/RNDIS/CDC
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_kmod-usb-net-asix=y
CONFIG_PACKAGE_kmod-usb-net-ax88179_178a=y
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y

# 常见 USB 串口
CONFIG_PACKAGE_kmod-usb-serial=y
CONFIG_PACKAGE_kmod-usb-serial-ftdi=y
CONFIG_PACKAGE_kmod-usb-serial-ch341=y
CONFIG_PACKAGE_kmod-usb-serial-cp210x=y
CONFIG_PACKAGE_kmod-usb-serial-option=y
CONFIG_PACKAGE_kmod-usb-net-wwan=y

# 存储与文件系统
CONFIG_PACKAGE_kmod-usb-storage=y
CONFIG_PACKAGE_kmod-usb-storage-extras=y
CONFIG_PACKAGE_kmod-usb-storage-uas=y
CONFIG_PACKAGE_block-mount=y
CONFIG_PACKAGE_e2fsprogs=y
CONFIG_PACKAGE_kmod-fs-ext4=y
CONFIG_PACKAGE_kmod-fs-vfat=y
CONFIG_PACKAGE_kmod-fs-exfat=y
CONFIG_PACKAGE_kmod-fs-ntfs=y

# 编码支持
CONFIG_PACKAGE_kmod-nls-base=y
CONFIG_PACKAGE_kmod-nls-utf8=y
CONFIG_PACKAGE_kmod-nls-cp437=y
CONFIG_PACKAGE_kmod-nls-cp936=y
CONFIG_PACKAGE_kmod-nls-iso8859-1=y

# 工具
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y
EOF_USB_ALL

# =========================================================
#  缺包自动禁用（兜底）— 放在最后，避免前面启用被误覆盖
# =========================================================
check_or_disable() {
  local pkg="$1"       # CONFIG_PACKAGE_* 名称（不含前缀）
  local path_glob="$2" # 例如 */luci-app-xxx/Makefile
  if ! find package feeds -maxdepth 3 -type f -path "${path_glob}" | grep -q .; then
    echo "CONFIG_PACKAGE_${pkg}=n" >> ./.config
    echo ">> WARN: ${pkg} not found in sources, disabled to avoid build error."
  fi
}

# LuCI 应用存在性检查
check_or_disable "luci-app-momo"     "*/luci-app-momo/Makefile"
check_or_disable "luci-app-nikki"    "*/luci-app-nikki/Makefile"
check_or_disable "luci-app-tailscale" "*/luci-app-tailscale/Makefile"

# tailscale 核心包常在 feeds/packages/net/tailscale
if ! find package feeds -maxdepth 3 -type f -path "*/tailscale/Makefile" | grep -q .; then
  echo "CONFIG_PACKAGE_tailscale=n" >> ./.config
  echo ">> WARN: tailscale core not found, disabled to avoid build error."
fi

# 若 feeds 中没有 sing-box，也兜底禁用（防止上面 SMALL/非 SMALL 误开）
if ! find package feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
fi

# Podman 存在性检查（仅当我们在上面启用了时提供兜底）
if [[ "${WRT_CONFIG,,}" != *"small"* && "${WRT_CONFIG,,}" != *"samll"* ]]; then
  check_or_disable "luci-app-podman" "*/luci-app-podman/Makefile"
  check_or_disable "podman"          "*/podman/Makefile"
fi
