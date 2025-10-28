#!/usr/bin/env bash
# Hardened Packages.sh — tolerate missing third-party packages
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
  luci-app-adguardhome \
  luci-app-momo luci-app-nikki momo nikki \
  luci-app-tailscale

# kiddin9/kwrt-packages（补充/兜底）
safe_sparse_clone main https://github.com/kiddin9/kwrt-packages \
  natter2 luci-app-natter2 \
  luci-app-cloudflarespeedtest \
  luci-app-caddy openwrt-caddy \
  luci-app-momo luci-app-nikki momo nikki \
  luci-app-tailscale

# Podman
safe_clone_into_package https://github.com/breeze303/openwrt-podman podman || true

# Lucky（若 feeds 没有则 vendor）
[ -d "${PKGDIR}/lucky" ] || safe_clone_into_package https://github.com/sirpdboy/lucky lucky || true
[ -d "${PKGDIR}/luci-app-lucky" ] || safe_clone_into_package https://github.com/sirpdboy/luci-app-lucky luci-app-lucky || true

# HomeProxy / sing-box（通常走 feeds；如需固定来源可在此 vendor）
# safe_clone_into_package https://github.com/immortalwrt/homeproxy luci-app-homeproxy
# safe_clone_into_package https://github.com/sbwml/openwrt_sing-box sing-box

# ---------- presence report ----------
echo ">> Presence report (should be 'OK'):"
for d in luci-app-momo luci-app-nikki luci-app-tailscale; do
  if [ -d "${PKGDIR}/${d}" ] || find feeds -maxdepth 3 -type d -name "${d}" | grep -q .; then
    echo "   ${d}: OK"
  else
    echo "   ${d}: MISSING (will be disabled later to avoid errors)"
  fi
done

echo ">> Third-party packages fetched successfully."
