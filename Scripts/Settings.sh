#!/usr/bin/env bash
set -e

CFG_FILE="./package/base-files/files/bin/config_generate"
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE"
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE"

# ---------- 基础 LuCI 选择 ----------
{
  echo "CONFIG_PACKAGE_luci=y"
  echo "CONFIG_LUCI_LANG_zh_Hans=y"
  echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y"
  echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y"
} >> ./.config

# ---------- 你手动要加的内容（如有） ----------
if [ -n "$WRT_PACKAGE" ]; then
  echo -e "$WRT_PACKAGE" >> ./.config
fi

# ---------- 高通/NSS 相关 ----------
DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
  echo "CONFIG_FEED_nss_packages=n" >> ./.config
  echo "CONFIG_FEED_sqm_scripts_nss=n" >> ./.config
  echo "CONFIG_PACKAGE_luci-app-sqm=y" >> ./.config
  echo "CONFIG_PACKAGE_sqm-scripts-nss=y" >> ./.config
  echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n" >> ./.config
  if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
  else
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
  fi
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
    find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
    echo "qualcommax set up nowifi successfully!"
  fi
fi

# ---------- dropbear 修正 ----------
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config

# ---------- 显式关闭容易引发依赖的包（稳态） ----------
cat >> ./.config <<'EOF_BLOCK_BAD'
CONFIG_PACKAGE_luci-app-wolplus=n
CONFIG_PACKAGE_luci-app-tailscale=n
CONFIG_PACKAGE_luci-app-advancedplus=n
CONFIG_PACKAGE_luci-theme-kucat=n
# feeds 可能带入的代理相关（容易引错）
CONFIG_PACKAGE_dae=n
CONFIG_PACKAGE_daed=n
CONFIG_PACKAGE_luci-app-v2raya=n
CONFIG_PACKAGE_v2raya=n
EOF_BLOCK_BAD

# ---------- 常用工具/应用（非 SMALL 默认启用） ----------
cat >> ./.config <<'EOF_TOOLS'
CONFIG_CGROUPS=y
CONFIG_CPUSETS=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_coreutils-base64=y
CONFIG_PACKAGE_coreutils=y
CONFIG_PACKAGE_btop=y
CONFIG_PACKAGE_luci-app-openlist2=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_lucky=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_tcping=y
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_luci-app-podman=y
CONFIG_PACKAGE_podman=y
CONFIG_PACKAGE_luci-app-caddy=y
CONFIG_PACKAGE_luci-app-filemanager=y
CONFIG_PACKAGE_luci-app-gost=y
CONFIG_PACKAGE_git-http=y
CONFIG_PACKAGE_luci-app-nginx=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_zoneinfo-asia=y
CONFIG_PACKAGE_bind-dig=y
CONFIG_PACKAGE_ss=y
CONFIG_PACKAGE_luci-app-turboacc=y
# 让发布页能看到它：
CONFIG_PACKAGE_luci-app-package-manager=y
EOF_TOOLS

# ---------- SMALL 体积保护 + 默认白名单 ----------
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected, applying minimal/safe package set"

    # 精简/开放的最小差异集
    cat >> ./.config << 'EOF_SM_MIN'
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_sing-box=y
EOF_SM_MIN

    # 保留的常用 LuCI
    cat >> ./.config << 'EOF_SM_WHITE'
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y
EOF_SM_WHITE

    # 显式关闭一些容易重的东西（空间/依赖）
    cat >> ./.config << 'EOF_SM_BLOCK'
CONFIG_PACKAGE_luci-app-openclash=n
CONFIG_PACKAGE_openclash=n
CONFIG_PACKAGE_luci-app-lucky=n
CONFIG_PACKAGE_lucky=n
CONFIG_PACKAGE_luci-app-dockerman=n
CONFIG_PACKAGE_dockerd=n
CONFIG_PACKAGE_containerd=n
CONFIG_PACKAGE_luci-app-podman=n
CONFIG_PACKAGE_podman=n
CONFIG_PACKAGE_luci-app-qbittorrent=n
CONFIG_PACKAGE_qbittorrent=n
CONFIG_PACKAGE_luci-app-gost=n
CONFIG_PACKAGE_gost=n
CONFIG_PACKAGE_luci-app-nginx=n
CONFIG_PACKAGE_nginx-mod-luci=n
CONFIG_PACKAGE_luci-app-filemanager=n
CONFIG_PACKAGE_btop=n
CONFIG_PACKAGE_bind-dig=n
CONFIG_PACKAGE_coreutils=n
CONFIG_PACKAGE_coreutils-base64=n
EOF_SM_BLOCK

    # 若 feeds 中没有 sing-box，则强制关闭，避免编译失败
    if ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d package/sing-box ]; then
      echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
      echo ">> WARNING: sing-box package not found, disabled to avoid build failure."
    fi
  ;;
esac

# ---------- 大闪存机型：避免 SQM 控制文件冲突 ----------
case "${WRT_CONFIG,,}" in
  *wifi-yes*|*wifi-no*)
    echo ">> Disable sqm-scripts-nss to prevent CONTROL conflict"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=n" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts=y" >> ./.config
    ;;
esac

# ---------- Podman 运行最优配置（非 SMALL） ----------
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL build: skip heavy Podman stack auto-enable"
    ;;
  *)
    echo ">> Enable full Podman stack (packages + kernel features)"

    cat >> ./.config << 'EOF_POD_PKGS'
CONFIG_PACKAGE_luci-app-podman=y
CONFIG_PACKAGE_podman=y
CONFIG_PACKAGE_conmon=y
CONFIG_PACKAGE_crun=y
CONFIG_PACKAGE_catatonit=y
CONFIG_PACKAGE_slirp4netns=y
CONFIG_PACKAGE_fuse-overlayfs=y
CONFIG_PACKAGE_uidmap=y
CONFIG_PACKAGE_netavark=y
CONFIG_PACKAGE_aardvark-dns=y
CONFIG_PACKAGE_containers-storage=y
CONFIG_PACKAGE_podman-compose=y
EOF_POD_PKGS

    cat >> ./.config << 'EOF_POD_KCFG'
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_PIDS=y
CONFIG_KERNEL_MEMCG=y
CONFIG_KERNEL_NAMESPACES=y
CONFIG_KERNEL_USER_NS=y
CONFIG_KERNEL_SECCOMP=y
CONFIG_KERNEL_SECCOMP_FILTER=y
CONFIG_KERNEL_KEYS=y
EOF_POD_KCFG

    mkdir -p ./files/etc/containers ./files/root/.config/containers ./files/root/.local/share/containers

    if [ "${PODMAN_EXTERNAL}" = "1" ] || [ "${PODMAN_EXTERNAL,,}" = "true" ]; then
      echo ">> Use external storage for Podman: /opt/podman"
      mkdir -p ./files/opt/podman ./files/etc/containers
      cat > ./files/etc/containers/storage.conf << 'EOF_STCONF'
[storage]
driver = "overlay"
graphroot = "/opt/podman"
runroot = "/run/containers/storage"
[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF_STCONF
    fi

    mkdir -p ./files/etc/sysctl.d
    cat > ./files/etc/sysctl.d/99-podman.conf << 'EOF_SYSCTL'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF_SYSCTL
    ;;
esac
