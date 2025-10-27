#!/usr/bin/env bash
# Hardened Packages.sh — tolerate missing third-party packages (e.g. luci-app-nginx removed upstream)
# This script is meant to run from the OpenWrt source root (./wrt/) where `package/` exists.
set -e

echo ">> Using hardened Packages.sh (safe sparse clone + conditional moves)"

PKGDIR="package"
mkdir -p "${PKGDIR}"

# --- Helper: safe sparse clone for selected paths ---
safe_sparse_clone() {
  local branch="$1"; shift
  local repo="$1"; shift
  local paths=("$@")

  local tmpdir
  tmpdir="$(mktemp -d)"
  echo ">> Sparse cloning ${repo} (${branch}) -> ${tmpdir}"
  git clone --depth=1 --filter=blob:none --sparse -b "${branch}" "${repo}" "${tmpdir}"
  pushd "${tmpdir}" >/dev/null

  if [ "${#paths[@]}" -gt 0 ]; then
    git sparse-checkout set --no-cone "${paths[@]}" || true
  fi

  for p in "${paths[@]}"; do
    if [ -d "${p}" ] || [ -f "${p}" ]; then
      echo "   + bringing ${p}"
      mv -f "${p}" "../${PKGDIR}/" 2>/dev/null || cp -a "${p}" "../${PKGDIR}/"
    else
      echo "   ! WARN: path '${p}' not found in ${repo}, skipping"
    fi
  done

  popd >/dev/null
  rm -rf "${tmpdir}"
}

# --- Helper: safe full clone of a single package into package/<name> ---
safe_clone_into_package() {
  local repo="$1"
  local name="$2"
  if [ -z "${name}" ]; then
    name="$(basename "${repo%%.git}")"
  fi
  echo ">> Cloning ${repo} -> ${PKGDIR}/${name}"
  rm -rf "${PKGDIR}/${name}"
  git clone --depth 1 --single-branch "${repo}" "${PKGDIR}/${name}"
}

# =============== Third-party sources ===============

# kenzok8/small-package（注意：个别目录可能上游删掉，已做容错）
safe_sparse_clone main https://github.com/kenzok8/small-package \
  daed-next luci-app-daed-next \
  gost luci-app-gost \
  luci-app-nginx \
  luci-app-adguardhome \
  luci-app-nikki \
  luci-app-momo

# luci-app-nginx 若已被上游移除，这里只提示，不中断
if [ ! -d "${PKGDIR}/luci-app-nginx" ]; then
  echo ">> luci-app-nginx not found via sparse checkout; possibly removed upstream, skipping."
fi

# kiddin9/kwrt-packages（按需抓取）
safe_sparse_clone main https://github.com/kiddin9/kwrt-packages \
  natter2 luci-app-natter2 \
  luci-app-cloudflarespeedtest \
  luci-app-caddy openwrt-caddy

# Podman（breeze303）
safe_clone_into_package https://github.com/breeze303/openwrt-podman podman

# Lucky（UI + core），仅当 feeds 没有对应目录时再 vendor
if [ ! -d "${PKGDIR}/lucky" ]; then
  safe_clone_into_package https://github.com/sirpdboy/lucky lucky || true
fi
if [ ! -d "${PKGDIR}/luci-app-lucky" ]; then
  safe_clone_into_package https://github.com/sirpdboy/luci-app-lucky luci-app-lucky || true
fi

# HomeProxy / sing-box 如需 vendor 可在此打开（否则走 feeds）
# safe_clone_into_package https://github.com/immortalwrt/homeproxy luci-app-homeproxy
# safe_clone_into_package https://github.com/sbwml/openwrt_sing-box sing-box

echo ">> Third-party packages fetched successfully."
# === 非 SMALL 机型：显式开启 luci-app-momo / luci-app-nikki ===
if [[ "${WRT_CONFIG,,}" != *"small"* && "${WRT_CONFIG,,}" != *"samll"* ]]; then
  echo "CONFIG_PACKAGE_luci-app-momo=y"  >> ./.config
  echo "CONFIG_PACKAGE_luci-app-nikki=y" >> ./.config
fi

# === 非 SMALL 机型：常见 USB/RNDIS/CDC & 常见网卡/蜂窝支持 ===
if [[ "${WRT_CONFIG,,}" != *"small"* && "${WRT_CONFIG,,}" != *"samll"* ]]; then
  cat >> ./.config <<'EOF_USB_NET_BIG'
# 基础 USB 栈 & Host 控制器（通用/兜底）
CONFIG_PACKAGE_kmod-usb-core=y
CONFIG_PACKAGE_kmod-usb2=y
CONFIG_PACKAGE_kmod-usb3=y
CONFIG_PACKAGE_kmod-usb-ehci=y
CONFIG_PACKAGE_kmod-usb-ohci=y
#（若你的机型已自带可自动裁掉，不影响编译）

# 常见 USB 以太网/RNDIS/CDC
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y

# 常见 USB 千兆网卡芯片
CONFIG_PACKAGE_kmod-usb-net-asix=y
CONFIG_PACKAGE_kmod-usb-net-ax88179_178a=y
CONFIG_PACKAGE_kmod-usb-net-rtl8152=y

# 手机/数据卡模式切换 & 工具
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y
CONFIG_PACKAGE_usb-modeswitch-data=y

# （可选）蜂窝/QMI/MBIM 用户态工具（很多随身网卡/手机共享不需要，但数据卡常用）
# CONFIG_PACKAGE_umbim=y
# CONFIG_PACKAGE_uqmi=y
# CONFIG_PACKAGE_kmod-usb-net-qmi-wwan=y
EOF_USB_NET_BIG
fi
