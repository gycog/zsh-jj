#!/usr/bin/env bash
#
# zsh-jj · fetch-jj.sh
# --------------------
# 下载 / 升级 jj (Jujutsu) 二进制到指定目录。
# 被 install-plugin.sh 和 functions/j-upgrade 共用,
# 让 zsh-jj 成为 "装了就能用" 的自包含插件。
#
# 依赖: curl, jq, tar, gzip, mktemp  (大多数发行版默认自带)
# 代理: 直接依赖 curl 的行为, 自动读取 http_proxy / https_proxy / all_proxy
#
# 用法:
#   tools/fetch-jj.sh [--dest DIR] [--version VER] [--check] [--force] [--quiet]
#
# 环境变量 (命令行参数优先):
#   ZSH_JJ_JJ_DIR      安装根目录 (bin 放在其下); 默认
#                      "${XDG_DATA_HOME:-$HOME/.local/share}/zsh-jj"
#   ZSH_JJ_JJ_VERSION  指定版本 tag (例如 v0.33.0); 默认 latest
#
# 退出码:
#   0   已是最新, 或升级成功
#   1   参数错误
#   2   依赖缺失
#   3   网络 / 下载 / 解压失败
#   4   架构不受支持

set -euo pipefail

readonly REPO="jj-vcs/jj"

# ---------- 默认值 ----------
DEST_ROOT="${ZSH_JJ_JJ_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/zsh-jj}"
TARGET_VERSION="${ZSH_JJ_JJ_VERSION:-latest}"
FORCE=0
QUIET=0
CHECK_ONLY=0

# ---------- 日志 ----------
if [[ -t 2 ]]; then
    _C_RED=$'\033[1;31m'; _C_GREEN=$'\033[1;32m'
    _C_YELLOW=$'\033[1;33m'; _C_BLUE=$'\033[1;34m'
    _C_RESET=$'\033[0m'
else
    _C_RED=''; _C_GREEN=''; _C_YELLOW=''; _C_BLUE=''; _C_RESET=''
fi
log_info() { (( QUIET )) || printf '%s[i]%s %s\n' "$_C_BLUE"   "$_C_RESET" "$*" >&2; }
log_ok()   { (( QUIET )) || printf '%s[+]%s %s\n' "$_C_GREEN"  "$_C_RESET" "$*" >&2; }
log_warn() {                 printf '%s[!]%s %s\n' "$_C_YELLOW" "$_C_RESET" "$*" >&2; }
log_err()  {                 printf '%s[x]%s %s\n' "$_C_RED"    "$_C_RESET" "$*" >&2; }

# ---------- 参数解析 ----------
usage() {
    cat <<'EOF'
tools/fetch-jj.sh - 下载 / 升级 jj 二进制

用法: fetch-jj.sh [选项]

选项:
  --dest DIR        安装根目录 (最终: DIR/bin/jj); 默认读 ZSH_JJ_JJ_DIR 或
                    "${XDG_DATA_HOME:-$HOME/.local/share}/zsh-jj"
  --version VER     指定版本 tag (如 v0.33.0); 默认 latest
  --check           只检查版本, 不下载 (退出码 0=已最新, 10=有新版本)
  --force           即使已是目标版本也重新下载
  --quiet           除错误外静默
  -h, --help        显示本帮助

环境变量:
  ZSH_JJ_JJ_DIR, ZSH_JJ_JJ_VERSION  (等价于同名参数, 命令行参数优先)
  http_proxy / https_proxy / all_proxy  由 curl 自动识别

退出码:
  0 成功 (或已最新)   1 参数错误
  2 依赖缺失          3 网络/下载/解压失败
  4 架构不支持        10 --check 发现有新版本
EOF
}

while (( $# > 0 )); do
    case "$1" in
        --dest)     DEST_ROOT="${2:?--dest 需要参数}"; shift 2 ;;
        --dest=*)   DEST_ROOT="${1#*=}"; shift ;;
        --version)  TARGET_VERSION="${2:?--version 需要参数}"; shift 2 ;;
        --version=*) TARGET_VERSION="${1#*=}"; shift ;;
        --force)    FORCE=1; shift ;;
        --quiet|-q) QUIET=1; shift ;;
        --check)    CHECK_ONLY=1; shift ;;
        -h|--help)  usage; exit 0 ;;
        *) log_err "未知参数: $1"; usage >&2; exit 1 ;;
    esac
done

# ---------- 依赖检查 ----------
_missing=()
for _bin in curl jq tar gzip mktemp uname; do
    command -v "$_bin" >/dev/null 2>&1 || _missing+=("$_bin")
done
if (( ${#_missing[@]} > 0 )); then
    log_err "缺少依赖: ${_missing[*]}"
    log_err "Debian/Ubuntu: sudo apt install -y curl jq tar gzip"
    log_err "macOS (brew) : brew install curl jq gnu-tar"
    exit 2
fi
unset _missing _bin

# ---------- 架构检测 ----------
detect_arch() {
    local os arch
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os/$arch" in
        Linux/x86_64)   echo "x86_64-unknown-linux-musl" ;;
        Linux/aarch64|Linux/arm64) echo "aarch64-unknown-linux-musl" ;;
        Darwin/x86_64)  echo "x86_64-apple-darwin" ;;
        Darwin/arm64|Darwin/aarch64) echo "aarch64-apple-darwin" ;;
        *)
            log_err "不支持的系统/架构: $os/$arch"
            exit 4
            ;;
    esac
}

# ---------- 版本工具 ----------
resolve_latest_tag() {
    local api resp tag
    api="https://api.github.com/repos/${REPO}/releases/latest"
    if ! resp="$(curl -fsSL \
                    -H 'Accept: application/vnd.github+json' \
                    -H 'User-Agent: zsh-jj-fetch-jj' \
                    "$api")"; then
        log_warn "GitHub API 失败, 尝试通过 releases 页面 302 解析 tag..."
        tag="$(curl -fsSI "https://github.com/${REPO}/releases/latest" 2>/dev/null \
               | awk 'BEGIN{IGNORECASE=1} /^location:/ {print $2}' \
               | sed -E 's#.*/tag/([^[:space:]]+).*#\1#' \
               | tr -d '\r\n')"
        if [[ -z "$tag" ]]; then
            log_err "无法获取最新版本, 请检查网络或设置代理"
            exit 3
        fi
        echo "$tag"
        return
    fi
    tag="$(echo "$resp" | jq -r '.tag_name // empty')"
    if [[ -z "$tag" || "$tag" == "null" ]]; then
        log_err "GitHub 返回的 release 数据格式异常"
        exit 3
    fi
    echo "$tag"
}

current_installed_version() {
    local bin="$1"
    [[ -x "$bin" ]] || { echo ""; return; }
    # `jj --version` 输出形如 "jj 0.33.0-deadbeef"
    "$bin" --version 2>/dev/null | awk '{print $2}' | awk -F- '{print "v"$1}' || echo ""
}

# ---------- 下载 + 安装 ----------
tmpdir=""
# shellcheck disable=SC2317  # invoked via trap, not directly
cleanup() {
    if [[ -n "${tmpdir:-}" && -d "$tmpdir" ]]; then
        rm -rf "$tmpdir"
    fi
    return 0
}
trap cleanup EXIT

download_and_install() {
    local tag="$1" arch="$2"
    local asset="jj-${tag}-${arch}.tar.gz"
    local url="https://github.com/${REPO}/releases/download/${tag}/${asset}"
    local bin_dir="${DEST_ROOT}/bin"
    tmpdir="$(mktemp -d)"

    log_info "下载 ${asset}"
    if ! curl -fL --progress-bar \
              --retry 3 --retry-delay 2 --connect-timeout 15 \
              -o "$tmpdir/$asset" \
              "$url"; then
        log_err "下载失败: $url"
        exit 3
    fi

    log_info "校验压缩包..."
    if ! gzip -t "$tmpdir/$asset" >/dev/null 2>&1 \
         || ! tar -tzf "$tmpdir/$asset" >/dev/null 2>&1; then
        log_err "压缩包损坏: $tmpdir/$asset"
        exit 3
    fi

    tar -xzf "$tmpdir/$asset" -C "$tmpdir"
    if [[ ! -x "$tmpdir/jj" ]]; then
        log_err "解压后未找到 jj 二进制"
        exit 3
    fi

    mkdir -p "$bin_dir"
    local target="$bin_dir/jj"
    # 原子替换, 避免并发运行时写坏文件
    mv -f "$tmpdir/jj" "$target.new"
    chmod +x "$target.new"
    mv -f "$target.new" "$target"

    log_ok "已安装 jj $tag 到 $target"
}

# ---------- 主流程 ----------
mkdir -p "$DEST_ROOT/bin"
ARCH="$(detect_arch)"
BIN="$DEST_ROOT/bin/jj"

if [[ "$TARGET_VERSION" == "latest" ]]; then
    log_info "查询 jj 最新 release..."
    TAG="$(resolve_latest_tag)"
else
    TAG="$TARGET_VERSION"
    [[ "$TAG" == v* ]] || TAG="v$TAG"
fi

INSTALLED="$(current_installed_version "$BIN")"

if (( CHECK_ONLY )); then
    if [[ -n "$INSTALLED" && "$INSTALLED" == "$TAG" ]]; then
        log_info "已是最新: $INSTALLED"
        exit 0
    fi
    if [[ -z "$INSTALLED" ]]; then
        log_info "jj 尚未安装, 目标版本: $TAG"
    else
        log_info "有新版本: $INSTALLED -> $TAG"
    fi
    exit 10
fi

if [[ -n "$INSTALLED" && "$INSTALLED" == "$TAG" && $FORCE -eq 0 ]]; then
    log_ok "已是最新: $INSTALLED ($BIN)"
    # 仍然标记最后一次检查时间 (由调用方触发, 这里只负责 stdout 返回路径)
    echo "$BIN"
    exit 0
fi

log_info "arch=$ARCH  target=$TAG  current=${INSTALLED:-<none>}  dest=$BIN"
download_and_install "$TAG" "$ARCH"

echo "$BIN"
exit 0
