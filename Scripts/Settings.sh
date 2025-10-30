#!/usr/bin/env bash
# Settings.sh — 统一功能开关与机型差异、附加驱动、稳态兜底
# 约定：在 .github/workflows 的 Custom Settings 步骤里，已先 export WRT_TARGET 再执行本脚本
set -e

# ====== 环境变量兜底与大小写安全处理 ======
WRT_IP="${WRT_IP:-192.168.1.1}"
WRT_NAME="${WRT_NAME:-OWRT}"
WRT_THEME="${WRT_THEME:-argon}"
WRT_CONFIG="${WRT_CONFIG:-}"
WRT_TARGET="${WRT_TARGET:-}"                     # 可能为空
WRT_TARGET_UPPER="$(printf '%s' "$WRT_TARGET" | tr '[:lower:]' '[:upper:]')"

# ====== 基础系统项 ======
CFG_FILE="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_FILE" ]; then
  sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE" || true
  sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE" || true
fi

# ====== 基础 LuCI 与主题 ======
{
  echo "CONFIG_PACKAGE_luci=y"
  echo "CONFIG_LUCI_LANG_zh_Hans=y"
  echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y"
  echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y"
  echo "CONFIG_PACKAGE_luci-theme-bootstrap=y"
} >> ./.config

# ====== 如果上游传入了额外包开关，拼进去 ======
if [ -n "${WRT_PACKAGE:-}" ]; then
  printf "%s\n" "${WRT_PACKAGE}" >> ./.config
fi

# ====== Qualcommax / NSS 相关 ======
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "$WRT_TARGET_UPPER" == *"QUALCOMMAX"* ]]; then
  {
    echo "CONFIG_FEED_nss_packages=n"
    echo "CONFIG_FEED_sqm_scripts_nss=n"
    echo "CONFIG_PACKAGE_luci-app-sqm=y"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=y"
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n"
  } >> ./.config

  # 12.2 还是 12.5
  if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
  else
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
  fi

  # nowifi 机型处理
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    if [ -d "$DTS_PATH" ]; then
      find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec \
        sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} + || true
      echo "qualcommax set up nowifi successfully!"
    fi
  fi
fi

# ====== dropbear 修正（某些分支名变动） ======
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config || true

# ====== 明确关闭不想带入的包（保持稳定） ======
cat >> ./.config <<'EOF_BLOCK_BAD'
CONFIG_PACKAGE_luci-app-advancedplus=n
CONFIG_PACKAGE_luci-theme-kucat=n
# 代理类常见问题源（保持稳定）
CONFIG_PACKAGE_dae=n
CONFIG_PACKAGE_daed=n
CONFIG_PACKAGE_luci-app-v2raya=n
CONFIG_PACKAGE_v2raya=n
EOF_BLOCK_BAD

# ====== 常用工具/应用（非 SMALL 默认启用；但 momo/nikki/tailscale 两版都开） ======
cat >> ./.config <<'EOF_TOOLS_COMMON'
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
# 让发布页能看到包管理器
CONFIG_PACKAGE_luci-app-package-manager=y
# tailscale：两版都开
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
# momo / nikki：两版都开（后面做缺包兜底）
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
EOF_TOOLS_COMMON

# ====== SMALL 体积策略 ======
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected — apply space-saving set"

    # 在 SMALL 里，homeproxy 默认关；sing-box 开（必要时）
    cat >> ./.config << 'EOF_SM_MIN'
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_sing-box=y
EOF_SM_MIN

    # SMALL 白名单
    cat >> ./.config << 'EOF_SM_WHITE'
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y
EOF_SM_WHITE

    # SMALL 对一些重包强制关闭
    cat >> ./.config << 'EOF_SM_BLOCK'
CONFIG_PACKAGE_luci-app-openclash=n
CONFIG_PACKAGE_openclash=n
CONFIG_PACKAGE_luci-app-dockerman=n
CONFIG_PACKAGE_dockerd=n
CONFIG_PACKAGE_containerd=n
CONFIG_PACKAGE_luci-app-qbittorrent=n
CONFIG_PACKAGE_qbittorrent=n
CONFIG_PACKAGE_nginx-mod-luci=n
CONFIG_PACKAGE_btop=n
CONFIG_PACKAGE_bind-dig=n
CONFIG_PACKAGE_coreutils=n
CONFIG_PACKAGE_coreutils-base64=n
EOF_SM_BLOCK

    # 如果没有 sing-box 源码，则关掉，避免失败
    if ! find package feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
      echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
      echo ">> WARNING: sing-box not found, disabled for SMALL to avoid failure."
    fi
  ;;
  *)
    # ====== 非 SMALL：Podman 运行时（完整） ======
    echo ">> Non-SMALL profile — enable Podman stack"
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

# ====== 大闪存机型：避免 SQM 控制文件冲突（按你之前的经验） ======
case "${WRT_CONFIG,,}" in
  *wifi-yes*|*wifi-no*)
    echo ">> Disable sqm-scripts-nss to prevent CONTROL conflict"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=n" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts=y" >> ./.config
    ;;
esac

# ====== “方案 B”：RNDIS/CDC 随身网卡（两版都加） ======
cat >> ./.config <<'EOF_USB_NET_ALL'
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y
EOF_USB_NET_ALL

# ====== 缺包自动置 n，避免卡编译（并提示） ======
check_or_disable() {
  # $1: Kconfig 符号（不带 CONFIG_PACKAGE_ 前缀时会自动补全） 例：luci-app-momo
  # $2: Makefile 搜索路径模式 例：*/luci-app-momo/Makefile
  local symbol="$1"
  local mk_glob="$2"
  local ksym="$symbol"
  if [[ "$ksym" != CONFIG_PACKAGE_* ]]; then
    ksym="CONFIG_PACKAGE_${symbol}"
  fi
  if ! find package feeds -maxdepth 3 -type f -path "$mk_glob" | grep -q .; then
    echo "${ksym}=n" >> ./.config
    echo ">> WARN: ${symbol} not found in sources, disabled to avoid build error."
  fi
}

# 针对 momo / nikki / tailscale（LuCI 与核心包）做存在性检查
check_or_disable "luci-app-momo"      "*/luci-app-momo/Makefile"
check_or_disable "luci-app-nikki"     "*/luci-app-nikki/Makefile"
check_or_disable "luci-app-tailscale" "*/luci-app-tailscale/Makefile"
if ! find package feeds -maxdepth 3 -type f -path "*/tailscale/Makefile" | grep -q .; then
  echo "CONFIG_PACKAGE_tailscale=n" >> ./.config
  echo ">> WARN: tailscale core not found, disabled to avoid build error."
fi

# 可选：homeproxy/sing-box 的存在性兜底（避免某些分支缺失）
if ! find package feeds -maxdepth 3 -type f -path "*/luci-app-homeproxy/Makefile" | grep -q .; then
  echo "CONFIG_PACKAGE_luci-app-homeproxy=n" >> ./.config
  echo ">> WARN: luci-app-homeproxy not found, disabled."
fi
if ! find package feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
  echo ">> WARN: sing-box not found, disabled."
fi

echo ">> Settings.sh finished successfully."
