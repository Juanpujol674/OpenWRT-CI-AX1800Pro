#!/usr/bin/env bash
# 用途：在合并 .config 之后、make defconfig 之前调用，幂等地启用 homeproxy+sing-box，禁用 xray/v2ray
set -e

CFG="${1:-.config}"

# 若传入路径不存在，则默认当前目录 .config
if [ ! -f "$CFG" ]; then
  CFG=".config"
fi

# 打开 luci-app-homeproxy
sed -i '/^CONFIG_PACKAGE_luci-app-homeproxy=/d' "$CFG"
echo 'CONFIG_PACKAGE_luci-app-homeproxy=y' >> "$CFG"

# 打开 sing-box
sed -i '/^CONFIG_PACKAGE_sing-box=/d' "$CFG"
echo 'CONFIG_PACKAGE_sing-box=y' >> "$CFG"

# 关闭其他核心，避免冲突
sed -i '/^CONFIG_PACKAGE_xray-core=/d' "$CFG"
echo 'CONFIG_PACKAGE_xray-core=n' >> "$CFG"
sed -i '/^CONFIG_PACKAGE_v2ray-core=/d' "$CFG"
echo 'CONFIG_PACKAGE_v2ray-core=n' >> "$CFG"

# 如需 GEO 数据，取消下面注释
# sed -i '/^CONFIG_PACKAGE_v2ray-geoip=/d' "$CFG" && echo 'CONFIG_PACKAGE_v2ray-geoip=y' >> "$CFG"
# sed -i '/^CONFIG_PACKAGE_v2ray-geosite=/d' "$CFG" && echo 'CONFIG_PACKAGE_v2ray-geosite=y' >> "$CFG"

echo "[ok] 已写入 $CFG 的 homeproxy/sing-box 设置"
