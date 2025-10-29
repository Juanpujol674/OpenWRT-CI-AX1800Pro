#!/usr/bin/env bash
# Hardened Packages.sh — 统一拉取第三方包，容忍上游缺失，并补齐 momo/nikki/tailscale（含 UI）
# 该脚本在 OpenWrt 源码根目录（./wrt/）下执行，目标目录为 ./wrt/package/
set -e

echo ">> Using hardened Packages.sh (safe sparse clone + conditional moves)"

PKGDIR="package"
mkdir -p "${PKGDIR}"

# --------- Helpers ----------
safe_sparse_clone() {
  local branch="$1"; shift
  local repo="$1"; shift
  local paths=("$@")
  local tmpdir; tmpdir="$(mktemp -d)"
  echo ">> Sparse cloning ${repo} (${branch})"
  git clone --depth=1 --filter=blob:none --sparse -b "${branch}" "${repo}" "${tmpdir}"
  pushd "${tmpdir}" >/dev/null
  if [ "${#paths[@]}" -gt 0 ]; then
    git sparse-checkout set --no-cone "${paths[@]}" || true
  fi
  for p in "${paths[@]}"; do
    if [ -d "${p}" ] || [ -f "${p}" ]; then
      echo "   + bring ${p}"
      mv -f "${p}" "../${PKGDIR}/" 2>/dev/null || cp -a "${p}" "../${PKGDIR}/"
    else
      echo "   ! WARN: path '${p}' not found in ${repo}, skip"
    fi
  done
  popd >/dev/null
  rm -rf "${tmpdir}"
}

safe_clone_into_package() {
  local repo="$1"
  local name="$2"
  [ -z "${name}" ] && name="$(basename "${repo%%.git}")"
  echo ">> Cloning ${repo} -> ${PKGDIR}/${name}"
  rm -rf "${PKGDIR}/${name}"
  git clone --depth 1 --single-branch "${repo}" "${PKGDIR}/${name}"
}

# --------- kenzok8/small-package（可能随时删包，需容错） ----------
safe_sparse_clone main https://github.com/kenzok8/small-package \
  daed-next luci-app-daed-next \
  gost luci-app-gost \
  luci-app-nginx \
  luci-app-adguardhome

# --------- kiddin9/kwrt-packages（补齐 momo/nikki/tailscale UI 等） ----------
# 注意：不同分支可能命名略有差异；这里尽量全列，缺什么就自动跳过
safe_sparse_clone main https://github.com/kiddin9/kwrt-packages \
  momo luci-app-momo \
  nikki luci-app-nikki \
  luci-app-tailscale

# 如果 luci-app-tailscale 没在 kwrt-packages 里，尝试备用来源（只在缺失时拉）
if [ ! -d "${PKGDIR}/luci-app-tailscale" ]; then
  echo ">> luci-app-tailscale not found in kwrt-packages, try fallback"
  # 常见备用：sbwml 或其他镜像（任选一个你自己稳定用的源）
  safe_clone_into_package https://github.com/sbwml/luci-app-tailscale luci-app-tailscale || true
fi

# --------- Podman（breeze303） ----------
safe_clone_into_package https://github.com/breeze303/openwrt-podman podman

# --------- Lucky（UI + core，若 feeds 已带则跳过） ----------
[ ! -d "${PKGDIR}/lucky" ] && safe_clone_into_package https://github.com/sirpdboy/lucky lucky || true
[ ! -d "${PKGDIR}/luci-app-lucky" ] && safe_clone_into_package https://github.com/sirpdboy/luci-app-lucky luci-app-lucky || true

# --------- 结果确认 ----------
echo ">> Summary of 3rd-party additions:"
ls -1 "${PKGDIR}" | grep -E 'momo|nikki|tailscale|podman|lucky|gost|adguard|nginx' || true
echo ">> Third-party packages fetched successfully."
