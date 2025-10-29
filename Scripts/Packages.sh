#!/usr/bin/env bash
# Vendor 指定第三方 LuCI/包，容忍上游变更/缺失并打印原因
set -e

PKGDIR="package"
mkdir -p "${PKGDIR}"

# 用法：
# UPDATE_PACKAGE <目标目录名> <owner/repo 或完整URL> <branch> [subpath] [aliases...]
# - 目标目录名：最终放到 package/<目标目录名>
# - subpath：可选；当上游是大杂烩时指定子目录（例如 packages/luci-app-xxx）
# - aliases：可选；空格分隔的“旧名/别名”，用于在 package 和 feeds 下清理同名残留
UPDATE_PACKAGE() {
  local dst="$1"; shift
  local repo="$1"; shift
  local branch="$1"; shift
  local subpath="${1:-}"; [ -n "${1:-}" ] && shift || true
  local aliases=("$@")

  # 组装 URL
  if [[ "$repo" == http* || "$repo" == git@* ]]; then
    local url="$repo"
  else
    local url="https://github.com/${repo}.git"
  fi

  echo "== UPDATE_PACKAGE: ${dst}  from  ${url}  [branch: ${branch}]  subpath: ${subpath:-<auto>}"

  # 1) 清理旧包（package 与 feeds 里的冲突名）
  for name in "$dst" "${aliases[@]}"; do
    [ -z "$name" ] && continue
    find "${PKGDIR}" -maxdepth 1 -type d -name "$name" -exec rm -rf {} + || true
    find feeds -maxdepth 3 -type d -name "$name" -exec echo "   - removing feed dir: {}" \; -exec rm -rf {} + || true
  done

  # 2) 克隆到临时目录
  local tmpdir; tmpdir="$(mktemp -d)"
  if ! git clone --depth=1 --single-branch -b "$branch" "$url" "$tmpdir"; then
    echo "!! WARN: 克隆失败：$url@$branch -> 跳过 ${dst}"
    rm -rf "$tmpdir"
    return 0
  fi

  # 3) 选择要拷贝的目录
  local srcdir=""
  if [ -n "$subpath" ]; then
    # 指定子目录
    if [ -d "$tmpdir/$subpath" ]; then
      srcdir="$tmpdir/$subpath"
    else
      echo "!! WARN: 指定 subpath 不存在：$subpath  in  $url ；跳过 ${dst}"
      rm -rf "$tmpdir"
      return 0
    fi
  else
    # 自动探测：优先找一级目录内包含 Makefile 的目录；若仓库根有 Makefile 也可用
    if [ -f "$tmpdir/Makefile" ]; then
      srcdir="$tmpdir"
    else
      # 找一级目录含 Makefile 的目录
      local candidates
      IFS=$'\n' read -r -d '' -a candidates < <(find "$tmpdir" -maxdepth 2 -mindepth 1 -type f -name Makefile -printf '%h\0')
      if [ "${#candidates[@]}" -gt 0 ]; then
        # 若存在与目标名同名的目录优先
        for c in "${candidates[@]}"; do
          if [[ "$(basename "$c")" == "$dst" ]]; then
            srcdir="$c"
            break
          fi
        done
        # 否则取第一个
        [ -z "$srcdir" ] && srcdir="${candidates[0]}"
      fi
    fi
  fi

  if [ -z "$srcdir" ] || [ ! -d "$srcdir" ]; then
    echo "!! WARN: 未找到可用的包目录（含 Makefile）：$url"
    rm -rf "$tmpdir"
    return 0
  fi

  # 4) 拷贝到 package/<dst>
  mkdir -p "${PKGDIR}/${dst}"
  # 仅复制源码（去掉 .git）
  (shopt -s dotglob; cp -a "$srcdir/"* "${PKGDIR}/${dst}/" 2>/dev/null || true)
  rm -rf "${PKGDIR}/${dst}/.git" "${PKGDIR}/${dst}/.github" || true

  # 5) 简要校验
  if [ ! -f "${PKGDIR}/${dst}/Makefile" ]; then
    echo "!! WARN: ${dst} 没有 Makefile（可能子目录层级不对），已放弃本次更新"
    rm -rf "${PKGDIR:?}/${dst}"
  else
    echo ">> OK: ${dst} 已更新到 package/${dst}"
  fi

  rm -rf "$tmpdir"
}

echo ">> Start vendoring custom packages into ${PKGDIR}"

# ===== 你要求的四个包 =====
# homeproxy（你给的是 VIKINGYFY/homeproxy；目标名取 luci-app-homeproxy 更直观）
UPDATE_PACKAGE "luci-app-homeproxy"   "VIKINGYFY/homeproxy"           "main"

# momo/nikki（来自 nikkinikki-org）
UPDATE_PACKAGE "luci-app-momo"        "nikkinikki-org/OpenWrt-momo"   "main"
UPDATE_PACKAGE "luci-app-nikki"       "nikkinikki-org/OpenWrt-nikki"  "main"

# tailscale 的 LuCI（你给的是 asvow 仓）
UPDATE_PACKAGE "luci-app-tailscale"   "asvow/luci-app-tailscale"      "main"

# ===== 你之前保留的其它第三方（可选，放后面避免相互覆盖）=====
# Podman（breeze303）
UPDATE_PACKAGE "podman" "https://github.com/breeze303/openwrt-podman" "master"

# kenzok8 / kiddin9 的聚合源（如仍需要，可继续用，但注意它们可能随时下架某些包）
# 建议只在需要时解开注释：
# UPDATE_PACKAGE "lucky"           "sirpdboy/lucky"                "master"
# UPDATE_PACKAGE "luci-app-lucky"  "sirpdboy/luci-app-lucky"       "master"
# UPDATE_PACKAGE "luci-app-gost"   "kenzok8/small-package"         "main"   "luci-app-gost"   "gost luci-app-gost"
# UPDATE_PACKAGE "openwrt-caddy"   "kiddin9/kwrt-packages"         "main"   "openwrt-caddy"
# UPDATE_PACKAGE "luci-app-caddy"  "kiddin9/kwrt-packages"         "main"   "luci-app-caddy"

echo ">> Done vendoring. Listing package/* heads:"
find package -maxdepth 1 -mindepth 1 -type d -printf " - %f\n" | sort || true
