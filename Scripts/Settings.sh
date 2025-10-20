#!/bin/bash
# ======================================================
# Scripts/Settings.sh  —— 通用设置
# - 不再写任何 CONFIG_FEED_*（会破坏 Kconfig）
# - QUALCOMMAX 平台保持 NSS 友好
# - SMALL 机型：体积保护 + 默认用普通 sqm-scripts（禁用 sqm-scripts-nss）
# - 末尾附 Podman 最优（仅非 SMALL）
# ======================================================
set -e

# ---------- LuCI 主题/标识 ----------
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# ---------- WiFi 默认 ----------
WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
  sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
  sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
  sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
  sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
  sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
  sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

# ---------- 系统默认 ----------
CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

# ---------- 基础 LuCI ----------
{
  echo "CONFIG_PACKAGE_luci=y"
  echo "CONFIG_LUCI_LANG_zh_Hans=y"
  echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y"
  echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y"
} >> ./.config

# ---------- 额外手动开关（来自 workflow 变量） ----------
if [ -n "$WRT_PACKAGE" ]; then
  echo -e "$WRT_PACKAGE" >> ./.config
fi

# ---------- QUALCOMMAX 平台（保留 NSS 相关习惯） ----------
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
  # 大内存版：保持 NSS 版 SQM（你原来的习惯）
  if [[ "${WRT_CONFIG,,}" != *"small"* && "${WRT_CONFIG,,}" != *"samll"* ]]; then
    echo "CONFIG_PACKAGE_luci-app-sqm=y"        >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts-nss=y"    >> ./.config
  fi

  # 固件分支选择
  echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
  if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
  else
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
  fi

  # 无 WiFi 变体：替换 nowifi dtsi
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
    echo "qualcommax set up nowifi successfully!"
  fi
fi

# ---------- 修复 dropbear ----------
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config

# ---------- 你常用的基础工具 ----------
{
  echo "CONFIG_CGROUPS=y"
  echo "CONFIG_CPUSETS=y"
  echo "CONFIG_PACKAGE_openssh-sftp-server=y"
  echo "CONFIG_PACKAGE_jq=y"
  echo "CONFIG_PACKAGE_coreutils-base64=y"
  echo "CONFIG_PACKAGE_coreutils=y"
  echo "CONFIG_PACKAGE_btop=y"
  echo "CONFIG_PACKAGE_luci-app-openlist2=y"
  echo "CONFIG_PACKAGE_luci-app-lucky=y"
  echo "CONFIG_PACKAGE_curl=y"
  echo "CONFIG_PACKAGE_tcping=y"
  echo "CONFIG_PACKAGE_cfdisk=y"
  echo "CONFIG_PACKAGE_luci-app-podman=y"
  echo "CONFIG_PACKAGE_luci-app-caddy=y"
  echo "CONFIG_PACKAGE_luci-app-filemanager=y"
  echo "CONFIG_PACKAGE_luci-app-gost=y"
  echo "CONFIG_PACKAGE_git-http=y"
  echo "CONFIG_PACKAGE_luci-app-nginx=y"
  echo "CONFIG_PACKAGE_luci-app-adguardhome=y"
  echo "CONFIG_PACKAGE_zoneinfo-asia=y"
  echo "CONFIG_PACKAGE_bind-dig=y"
  echo "CONFIG_PACKAGE_ss=y"
  echo "CONFIG_PACKAGE_luci-app-turboacc=y"
} >> ./.config

# ---------- SMALL 体积保护 ----------
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected, applying minimal/safe package set"

    # 科学最小集
    cat >> ./.config << 'EOF_SM_MIN'
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_sing-box=y
EOF_SM_MIN

    # 常用白名单
    cat >> ./.config << 'EOF_SM_WHITE'
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y
EOF_SM_WHITE

    # 重型组件统统关
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

    # SMALL 机型默认不用 NSS 版 SQM，避免 CONTROL 冲突 & 节省体积
    echo "CONFIG_PACKAGE_sqm-scripts-nss=n" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts=y"     >> ./.config
  ;;
esac

# ---------- Podman 友好（仅非 SMALL） ----------
case "${WRT_CONFIG,,}" in
  *small*|*samll*) : ;;
  *)
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

    mkdir -p ./files/etc/sysctl.d
    cat > ./files/etc/sysctl.d/99-podman.conf << 'EOF_SYSCTL'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF_SYSCTL
  ;;
esac

echo ">> Settings.sh applied OK."
