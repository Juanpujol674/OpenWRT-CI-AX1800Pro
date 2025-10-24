#!/usr/bin/env bash
# 追加启用 luci-app-homeproxy + sing-box（若存在），用于非 SMALL 机型
set -e
if [[ "${WRT_CONFIG,,}" == *"small"* || "${WRT_CONFIG,,}" == *"samll"* ]]; then
  echo "[homeproxy-append] SMALL 配置，跳过 homeproxy/sing-box 追加"
  exit 0
fi

touch .config

# 强制打开 LuCI + 后端
grep -q '^CONFIG_PACKAGE_luci-app-homeproxy=' .config && sed -i 's/^CONFIG_PACKAGE_luci-app-homeproxy=.*/CONFIG_PACKAGE_luci-app-homeproxy=y/' .config || echo 'CONFIG_PACKAGE_luci-app-homeproxy=y' >> .config
grep -q '^CONFIG_PACKAGE_sing-box=' .config && sed -i 's/^CONFIG_PACKAGE_sing-box=.*/CONFIG_PACKAGE_sing-box=y/' .config || echo 'CONFIG_PACKAGE_sing-box=y' >> .config

# 可选：sing-box geo 数据（如有对应包）
# echo 'CONFIG_PACKAGE_sing-box-geoip=y' >> .config || true
# echo 'CONFIG_PACKAGE_sing-box-geosite=y' >> .config || true

echo "[homeproxy-append] 已写入 homeproxy/sing-box 相关开关"
