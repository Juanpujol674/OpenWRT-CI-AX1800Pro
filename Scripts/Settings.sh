#!/usr/bin/env bash
set -e

# =========================
# Base system tweaks
# =========================
CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

# =========================
# LuCI basics
# =========================
{
  echo "CONFIG_PACKAGE_luci=y"
  echo "CONFIG_LUCI_LANG_zh_Hans=y"
  echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y"
  echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y"
  echo "CONFIG_PACKAGE_luci-theme-bootstrap=y"
  # 第三方 LuCI 常用的兼容层
  echo "CONFIG_PACKAGE_luci-compat=y"
} >> ./.config

# 手动附加（来自 workflow inputs.WRT_PACKAGE）
if [ -n "$WRT_PACKAGE" ]; then
  echo -e "$WRT_PACKAGE" >> ./.config
fi

# =========================
# Qualcomm / NSS
# =========================
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
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
    echo "qualcommax set up nowifi successfully!"
  fi
fi

# dropbear 配置项改名兼容
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config || true

# =========================
# 明确不要的包（保持稳态）
# =========================
cat >> ./.config <<'EOF_BLOCK_BAD'
CONFIG_PACKAGE_luci-app-advancedplus=n
CONFIG_PACKAGE_luci-theme-kucat=n
# feeds 可能带入的代理相关（容易引错）
CONFIG_PACKAGE_dae=n
CONFIG_PACKAGE_daed=n
CONFIG_PACKAGE_luci-app-v2raya=n
CONFIG_PACKAGE_v2raya=n
EOF_BLOCK_BAD

# =========================
# 常用工具（非 SMALL 默认启用）
# =========================
cat >> ./.config <<'EOF_TOOLS'
CONFIG_CGROUPS=y
CONFIG_CPUSETS=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_coreutils-base64=y
CONFIG_PACKAGE_coreutils=y
CONFIG_PACKAGE_btop=y
CONFIG_PACKAGE_luci-app-openlist2=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_lucky=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_tcping=y
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_luci-app-podman=y
CONFIG_PACKAGE_podman=y
CONFIG_PACKAGE_luci-app-caddy=y
CONFIG_PACKAGE_luci-app-filemanager=y
CONFIG_PACKAGE_luci-app-gost=y
CONFIG_PACKAGE_git-http=y
CONFIG_PACKAGE_luci-app-nginx=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_zoneinfo-asia=y
CONFIG_PACKAGE_bind-dig=y
CONFIG_PACKAGE_ss=y
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-package-manager=y
# Tailscale（两种版本都集成；这里先给默认，大/小内存下方分别补）
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
# TUN 驱动（tailscale 需要）
CONFIG_PACKAGE_kmod-tun=y
EOF_TOOLS

# =========================
# SMALL 体积保护 + 白名单
# =========================
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected, applying minimal/safe package set"

    # SMALL 保留/调整
    cat >> ./.config << 'EOF_SM_MIN'
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_sing-box=y
EOF_SM_MIN

    cat >> ./.config << 'EOF_SM_WHITE'
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y
# SMALL 也启用 tailscale（按你的要求）
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
EOF_SM_WHITE

    # 为 SMALL 显式关闭一些重依赖
    cat >> ./.config << 'EOF_SM_BLOCK'
CONFIG_PACKAGE_luci-app-openclash=n
CONFIG_PACKAGE_openclash=n
CONFIG_PACKAGE_luci-app-lucky=n
CONFIG_PACKAGE_lucky=n
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
CONFIG_PACKAGE_luci-app-filemanager=n
CONFIG_PACKAGE_btop=n
CONFIG_PACKAGE_bind-dig=n
CONFIG_PACKAGE_coreutils=n
CONFIG_PACKAGE_coreutils-base64=n
EOF_SM_BLOCK

    # 无 sing-box 源时，避免失败
    if ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d package/sing-box ]; then
      echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
      echo ">> WARNING: sing-box package not found, disabled to avoid build failure."
    fi
  ;;
esac

# =========================
# 大闪存：避免 SQM CONTROL 冲突
# =========================
case "${WRT_CONFIG,,}" in
  *wifi-yes*|*wifi-no*)
    echo ">> Disable sqm-scripts-nss to prevent CONTROL conflict"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=n" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts=y" >> ./.config
    ;;
esac

# =========================
# Podman 运行栈（非 SMALL）
# =========================
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL build: skip heavy Podman stack auto-enable"
    ;;
  *)
    echo ">> Enable full Podman stack (packages + kernel features)"
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

    mkdir -p ./files/etc/containers ./files/root/.config/containers ./files/root/.local/share/containers
    mkdir -p ./files/etc/sysctl.d
    cat > ./files/etc/sysctl.d/99-podman.conf << 'EOF_SYSCTL'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF_SYSCTL
    ;;
esac

# =========================
# 大内存：RNDIS/CDC 随身网卡支持
# =========================
if [[ "${WRT_CONFIG,,}" != *"small"* && "${WRT_CONFIG,,}" != *"samll"* ]]; then
  cat >> ./.config <<'EOF_USB_NET_BIG'
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y
EOF_USB_NET_BIG
fi

# =========================
# 非 SMALL：显式开启 momo / nikki
# =========================
if [[ "${WRT_CONFIG,,}" != *"small"* && "${WRT_CONFIG,,}" != *"samll"* ]]; then
  echo "CONFIG_PACKAGE_luci-app-momo=y"  >> ./.config
  echo "CONFIG_PACKAGE_luci-app-nikki=y" >> ./.config
fi

# =========================
# 兜底存在性检查（源里没有则禁用避免红叉）
# =========================
check_or_disable() {
  local pkg="$1"       # e.g. luci-app-momo
  local path_glob="$2" # e.g. */luci-app-momo/Makefile
  if ! find package feeds -maxdepth 4 -type f -path "${path_glob}" | grep -q .; then
    echo "CONFIG_PACKAGE_${pkg}=n" >> ./.config
    echo ">> WARN: ${pkg} not found in sources, disabled to avoid build error."
  fi
}

check_or_disable "luci-app-momo"      "*/luci-app-momo/Makefile"
check_or_disable "luci-app-nikki"     "*/luci-app-nikki/Makefile"
check_or_disable "luci-app-tailscale" "*/luci-app-tailscale/Makefile"

# tailscale 核心包通常在 feeds/packages/net/tailscale
if ! find package feeds -maxdepth 5 -type f -path "*/tailscale/Makefile" | grep -q .; then
  echo "CONFIG_PACKAGE_tailscale=n" >> ./.config
  echo ">> WARN: tailscale core not found, disabled."
fi
