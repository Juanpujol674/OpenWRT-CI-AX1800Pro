#!/usr/bin/env bash
# Hardened Packages.sh — tolerate missing third-party packages
# Run from OpenWrt source root (./wrt/). Will place packages under ./package/
set -e

echo ">> Using hardened Packages.sh (safe sparse clone + conditional moves)"

PKGDIR="package"
mkdir -p "${PKGDIR}"

# ---------- helpers ----------
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

# ---------- third-party sources ----------

# kenzok8/small-package（常见扩展）
safe_sparse_clone main https://github.com/kenzok8/small-package \
  daed-next luci-app-daed-next \
  gost luci-app-gost \
  luci-app-nginx \
  luci-app-adguardhome

if [ ! -d "${PKGDIR}/luci-app-nginx" ]; then
  echo ">> luci-app-nginx not found via sparse checkout; skipping (may be deprecated upstream)"
fi

# kiddin9/kwrt-packages（加入 momo/nikki）
safe_sparse_clone main https://github.com/kiddin9/kwrt-packages \
  natter2 luci-app-natter2 \
  luci-app-cloudflarespeedtest \
  luci-app-caddy openwrt-caddy \
  luci-app-momo luci-app-nikki momo nikki

# 兜底：如 kwrt-packages 没有 momo/nikki，再尝试 small-package
if [ ! -d "${PKGDIR}/luci-app-momo" ] || [ ! -d "${PKGDIR}/luci-app-nikki" ]; then
  safe_sparse_clone main https://github.com/kenzok8/small-package \
    luci-app-momo luci-app-nikki momo nikki
fi

# Podman（breeze303）
safe_clone_into_package https://github.com/breeze303/openwrt-podman podman || true

# Lucky（若 feeds 没有则 vendor）
if [ ! -d "${PKGDIR}/lucky" ]; then
  safe_clone_into_package https://github.com/sirpdboy/lucky lucky || true
fi
if [ ! -d "${PKGDIR}/luci-app-lucky" ]; then
  safe_clone_into_package https://github.com/sirpdboy/luci-app-lucky luci-app-lucky || true
fi

# HomeProxy / sing-box（通常走 feeds；如需固定来源可在此 vendor）
# safe_clone_into_package https://github.com/immortalwrt/homeproxy luci-app-homeproxy
# safe_clone_into_package https://github.com/sbwml/openwrt_sing-box sing-box

echo ">> Third-party packages fetched successfully."
