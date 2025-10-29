#!/usr/bin/env bash
# Hardened Packages.sh — 容忍第三方上游移除包，并尽量给出缺失原因
set -e
echo ">> Using hardened Packages.sh (safe sparse clone + conditional moves)"

PKGDIR="package"
mkdir -p "${PKGDIR}"

safe_sparse_clone() {
  local branch="$1"; shift
  local repo="$1"; shift
  local paths=("$@")
  local tmpdir; tmpdir="$(mktemp -d)"
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
  local repo="$1"; local name="$2"
  [ -z "${name}" ] && name="$(basename "${repo%%.git}")"
  echo ">> Cloning ${repo} -> ${PKGDIR}/${name}"
  rm -rf "${PKGDIR}/${name}"
  git clone --depth 1 --single-branch "${repo}" "${PKGDIR}/${name}"
}

# --- 你的第三方源 ---

# 1) kenzok8/small-package
safe_sparse_clone main https://github.com/kenzok8/small-package \
  daed-next luci-app-daed-next \
  gost luci-app-gost \
  luci-app-nginx \
  luci-app-adguardhome \
  luci-app-momo \
  luci-app-nikki

# 2) kiddin9/kwrt-packages （兜底再试一遍 momo/nikki）
safe_sparse_clone main https://github.com/kiddin9/kwrt-packages \
  natter2 luci-app-natter2 \
  luci-app-cloudflarespeedtest \
  luci-app-caddy openwrt-caddy \
  luci-app-momo \
  luci-app-nikki

# 3) Podman（breeze303）
safe_clone_into_package https://github.com/breeze303/openwrt-podman podman

# 4) Lucky（若 feeds 没有则另行拉取）
[ -d "${PKGDIR}/lucky" ] || safe_clone_into_package https://github.com/sirpdboy/lucky lucky || true
[ -d "${PKGDIR}/luci-app-lucky" ] || safe_clone_into_package https://github.com/sirpdboy/luci-app-lucky luci-app-lucky || true

# 5) HomeProxy / sing-box（通常 feeds 内已有，如需 vendor 可按你需求打开）
# safe_clone_into_package https://github.com/immortalwrt/homeproxy luci-app-homeproxy
# safe_clone_into_package https://github.com/sbwml/openwrt_sing-box sing-box

# --- 检查 momo/nikki 是否到位，给出明确提示 ---
for p in luci-app-momo luci-app-nikki; do
  if [ ! -d "package/${p}" ]; then
    echo "!! WARN: ${p} 未从第三方仓库获取到。"
    echo "   - 已尝试：kenzok8/small-package / kiddin9/kwrt-packages"
    echo "   - 如需强制集成，请确认上游仍存在该目录，或提供稳定仓库地址再 vendor。"
  fi
done

echo ">> Third-party packages fetched successfully."
