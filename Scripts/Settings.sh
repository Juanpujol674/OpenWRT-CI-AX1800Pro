#!/usr/bin/env bash
# Settings.sh — 仅在源码存在时开启 homeproxy/sing-box；并保留你现有的 Podman/USB/SMALL 逻辑
set -euo pipefail

CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

append_cfg() { printf '%s\n' "$*" >> ./.config; }
have_pkg() { find package feeds -maxdepth 3 -type f -path "$1" | grep -q .; }

# 基础 LuCI
append_cfg "
CONFIG_PACKAGE_luci=y
CONFIG_LUCI_LANG_zh_Hans=y
CONFIG_PACKAGE_luci-theme-$WRT_THEME=y
CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y
CONFIG_PACKAGE_luci-theme-bootstrap=y
"

# 手动附加
[ -n "${WRT_PACKAGE:-}" ] && printf "%s\n" "${WRT_PACKAGE}" >> .config

# Qualcomm/NSS（保持你原逻辑，略）
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
  append_cfg "
CONFIG_FEED_nss_packages=n
CONFIG_FEED_sqm_scripts_nss=n
CONFIG_PACKAGE_luci-app-sqm=y
CONFIG_PACKAGE_sqm-scripts-nss=y
CONFIG_NSS_FIRMWARE_VERSION_11_4=n
"
  if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then append_cfg "CONFIG_NSS_FIRMWARE_VERSION_12_2=y"; else append_cfg "CONFIG_NSS_FIRMWARE_VERSION_12_5=y"; fi
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
  fi
fi

# dropbear 修正
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config || true

# 不建议拉入的包
append_cfg "
CONFIG_PACKAGE_luci-app-advancedplus=n
CONFIG_PACKAGE_luci-theme-kucat=n
CONFIG_PACKAGE_dae=n
CONFIG_PACKAGE_daed=n
CONFIG_PACKAGE_luci-app-v2raya=n
CONFIG_PACKAGE_v2raya=n
"

# 常用（非 SMALL 默认）
append_cfg "
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
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
"

# SMALL 体积保护
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    append_cfg "
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_sing-box=y
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
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
"
    # 若源码缺失则关闭 sing-box
    have_pkg "*/sing-box/Makefile" || append_cfg "CONFIG_PACKAGE_sing-box=n"
  ;;
esac

# 大闪存机型：SQM 冲突回避
case "${WRT_CONFIG,,}" in
  *wifi-yes*|*wifi-no*)
    append_cfg "
CONFIG_PACKAGE_sqm-scripts-nss=n
CONFIG_PACKAGE_sqm-scripts=y
"
  ;;
esac

# Podman 运行最优（非 SMALL）
case "${WRT_CONFIG,,}" in
  *small*|*samll*) : ;;
  *)
    append_cfg "
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
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_PIDS=y
CONFIG_KERNEL_MEMCG=y
CONFIG_KERNEL_NAMESPACES=y
CONFIG_KERNEL_USER_NS=y
CONFIG_KERNEL_SECCOMP=y
CONFIG_KERNEL_SECCOMP_FILTER=y
CONFIG_KERNEL_KEYS=y
"
    mkdir -p ./files/etc/sysctl.d
    cat > ./files/etc/sysctl.d/99-podman.conf << 'EOF_SYSCTL'
net.ipv4.ip_forward=1
net.ip6.conf.all.forwarding=1
EOF_SYSCTL
  ;;
esac

# 大/小内存都：RNDIS/CDC 随身网卡
append_cfg "
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y
"

# 仅在源码存在时才打开 homeproxy & sing-box（避免硬开导致失败）
have_pkg "*/luci-app-homeproxy/Makefile" && append_cfg "CONFIG_PACKAGE_luci-app-homeproxy=y" || append_cfg "CONFIG_PACKAGE_luci-app-homeproxy=n"
have_pkg "*/sing-box/Makefile"         && append_cfg "CONFIG_PACKAGE_sing-box=y"         || append_cfg "CONFIG_PACKAGE_sing-box=n"
