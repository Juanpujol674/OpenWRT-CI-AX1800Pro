#!/usr/bin/env bash
set -e

# SMALL 场景的外源拉取（尽量轻量）
git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b "$branch" --single-branch --filter=blob:none --sparse "$repourl"
  repodir=$(basename "$repourl")
  cd "$repodir"
  git sparse-checkout set "$@"
  mkdir -p ../package
  mv -f "$@" ../package
  cd .. && rm -rf "$repodir"
}

# Lucky（App+二进制）—— SMALL 默认关闭，但保留源码以便手动打开
rm -rf package/lucky || true
git clone --depth=1 https://github.com/sirpdboy/luci-app-lucky.git package/lucky

# 提供 sing-box 包，满足 luci-app-homeproxy 依赖（如果你手动打开它时）
if [ ! -d "package/sing-box" ] && ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q .; then
  echo ">> sing-box not found, cloning sbwml/sing-box (SMALL) ..."
  rm -rf package/*/sing-box feeds/*/sing-box || true
  git clone --depth=1 https://github.com/sbwml/sing-box package/sing-box && echo ">> Added sing-box successfully."
fi

# 依旧装全 feeds，保证依赖
./scripts/feeds install -a
