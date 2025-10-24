#!/usr/bin/env bash
# Hardened Packages.sh — tolerate missing third‑party packages (e.g. luci-app-nginx removed upstream)
# This script is meant to run from the OpenWrt source root (./wrt/) where `package/` exists.
set -e

echo ">> Using hardened Packages.sh (safe sparse clone + conditional moves)"

PKGDIR="package"

# Ensure package dir exists
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

  # Set the sparse paths if any; otherwise just skip
  if [ "${#paths[@]}" -gt 0 ]; then
    git sparse-checkout set --no-cone "${paths[@]}" || true
  fi

  # Move existing items only
  for p in "${paths[@]}"; do
    if [ -d "${p}" ] || [ -f "${p}" ]; then
      echo "   + bringing ${p}"
      # prefer move; if cross-device, fallback to copy
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
  # If exists, remove and reclone to keep fresh
  rm -rf "${PKGDIR}/${name}"
  git clone --depth 1 --single-branch "${repo}" "${PKGDIR}/${name}"
}

# --- Your third-party sources ---

# kenzok8/small-package (some paths may disappear upstream; we guard them)
safe_sparse_clone main https://github.com/kenzok8/small-package \
  daed-next luci-app-daed-next \
  gost luci-app-gost \
  luci-app-nginx \
  luci-app-adguardhome

# If luci-app-nginx was not present in sparse list, try to fetch it from full repo as fallback (optional)
if [ ! -d "${PKGDIR}/luci-app-nginx" ]; then
  echo ">> luci-app-nginx not found via sparse checkout; skipping (package may be deprecated upstream)"
fi

# kiddin9/kwrt-packages (selected)
safe_sparse_clone main https://github.com/kiddin9/kwrt-packages \
  natter2 luci-app-natter2 \
  luci-app-cloudflarespeedtest \
  luci-app-caddy openwrt-caddy

# Podman (breeze303)
safe_clone_into_package https://github.com/breeze303/openwrt-podman podman

# Optional: Lucky (UI + core) – only clone if not already in feeds
if [ ! -d "${PKGDIR}/lucky" ]; then
  safe_clone_into_package https://github.com/sirpdboy/lucky lucky || true
fi
if [ ! -d "${PKGDIR}/luci-app-lucky" ]; then
  safe_clone_into_package https://github.com/sirpdboy/luci-app-lucky luci-app-lucky || true
fi

# Optional: HomeProxy / sing-box (use your preferred source; here we rely on feeds by default)
# If you want to vendor them, uncomment the following lines with your known-good repos:
# safe_clone_into_package https://github.com/immortalwrt/homeproxy luci-app-homeproxy
# safe_clone_into_package https://github.com/sbwml/openwrt_sing-box sing-box

echo ">> Third-party packages fetched successfully."
