#!/bin/bash

#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
	#修改WIFI地区
	sed -i "s/country='.*'/country='CN'/g" $WIFI_UC
	#修改WIFI加密
	sed -i "s/encryption='.*'/encryption='psk2+ccmp'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#取消nss相关feed
	echo "CONFIG_FEED_nss_packages=n" >> ./.config
	echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
	#开启sqm-nss插件
	echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
	echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
	#设置NSS版本
	echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
	if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
	else
		echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
	fi
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi

# #修复dropbear
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config

# 不必要或冲突的插件关闭
echo "CONFIG_PACKAGE_luci-app-wolplus=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-tailscale=n" >> ./.config
echo "CONFIG_PACKAGE_luci-app-advancedplus=n" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-kucat=n" >> ./.config

# Docker --cpuset-cpus="0-1"
echo "CONFIG_CGROUPS=y" >> ./.config
echo "CONFIG_CPUSETS=y" >> ./.config

# 基础工具支持
echo "CONFIG_PACKAGE_openssh-sftp-server=y" >> ./.config
echo "CONFIG_PACKAGE_jq=y" >> ./.config
echo "CONFIG_PACKAGE_coreutils-base64=y" >> ./.config
echo "CONFIG_PACKAGE_coreutils=y" >> ./.config
echo "CONFIG_PACKAGE_btop=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-openlist2=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-lucky=y" >> ./.config
echo "CONFIG_PACKAGE_curl=y" >> ./.config
echo "CONFIG_PACKAGE_tcping=y" >> ./.config
echo "CONFIG_PACKAGE_cfdisk=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-podman=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-lucky=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-caddy=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-filemanager=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-gost=y" >> ./.config
echo "CONFIG_PACKAGE_git-http=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-nginx=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-adguardhome=y" >> ./.config
echo "CONFIG_PACKAGE_zoneinfo-asia=y" >> ./.config 
echo "CONFIG_PACKAGE_bind-dig=y" >> ./.config
echo "CONFIG_PACKAGE_ss=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-turboacc=y" >> ./.config

# =========================
# SMALL 机型体积保护（small/samll）
# =========================
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected, applying minimal/safe package set"

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
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y
EOF_SM_WHITE

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

    # sing-box 降级保护
    if ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d package/sing-box ]; then
      echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
      echo ">> WARNING: sing-box package not found, disabled to avoid build failure."
    fi
    ;;
esac

# ============================================
# 大闪存机型防护：禁用 sqm-scripts-nss 打包冲突
# ============================================
case "${WRT_CONFIG,,}" in
  *wifi-yes*|*wifi-no*)
    echo ">> Disable sqm-scripts-nss to prevent CONTROL conflict"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=n" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts=y" >> ./.config
    ;;
esac
