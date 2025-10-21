#!/bin/bash
set -e

# ---------- 主题 / IP / 标识 ----------
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g"  $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

# ---------- Wi-Fi 默认项（存在其一则改） ----------
WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
  sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" "$WIFI_SH"
  sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" "$WIFI_SH"
elif [ -f "$WIFI_UC" ]; then
  sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" "$WIFI_UC"
  sed -i "s/key='.*'/key='$WRT_WORD'/g" "$WIFI_UC"
  sed -i "s/country='.*'/country='CN'/g" "$WIFI_UC"
  sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" "$WIFI_UC"
fi

# ---------- 系统默认 IP / 主机名 ----------
CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

# ---------- 基础 LuCI 选择 ----------
{
  echo "CONFIG_PACKAGE_luci=y"
  echo "CONFIG_LUCI_LANG_zh_Hans=y"
  echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y"
  echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y"
} >> ./.config

# ---------- 你手动要加的内容（如有） ----------
if [ -n "$WRT_PACKAGE" ]; then
  echo -e "$WRT_PACKAGE" >> ./.config
fi

# ---------- 高通 / nowifi dtsi 替换 ----------
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
  # 仅做 no-wifi 机型 dtsi 替换；不再动任何 feed / NSS 选择
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
    echo "qualcommax set up nowifi successfully!"
  fi
fi

# ---------- dropbear 修正 ----------
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config

# ---------- 显式关闭容易引发依赖/冲突的包 ----------
cat >> ./.config <<'EOF_BLOCK_BAD'
CONFIG_PACKAGE_luci-app-wolplus=n
CONFIG_PACKAGE_luci-app-tailscale=n
CONFIG_PACKAGE_luci-app-advancedplus=n
CONFIG_PACKAGE_luci-theme-kucat=n
# feeds 可能带入的代理相关（容易引错）
CONFIG_PACKAGE_dae=n
CONFIG_PACKAGE_daed=n
CONFIG_PACKAGE_luci-app-v2raya=n
CONFIG_PACKAGE_v2raya=n
EOF_BLOCK_BAD

# ---------- 常用工具（大内存机型会保留；SMALL 在下面会屏蔽） ----------
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
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_tcping=y
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_luci-app-podman=y
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
EOF_TOOLS

# ---------- SMALL 体积保护（不再在此切换 SQM/NSS） ----------
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected, applying minimal/safe package set"

    # 轻量科学
    cat >> ./.config << 'EOF_SM_MIN'
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_sing-box=y
EOF_SM_MIN

    # 白名单
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

    # 大体积/重依赖包禁用
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
  ;;
esac

# ---------- SQM/NSS 一致性守护（仅修正；不改变你的选择） ----------
# 如果用户在 Config/*.txt 里启用了 sqm-scripts-nss，就确保普通 sqm 被关闭，避免并存冲突
if grep -q '^CONFIG_PACKAGE_sqm-scripts-nss=y' ./.config; then
  sed -i '/^CONFIG_PACKAGE_sqm-scripts=/d' ./.config
  echo 'CONFIG_PACKAGE_sqm-scripts=n' >> ./.config
fi
