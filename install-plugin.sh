#!/usr/bin/env bash
#
# zsh-jj · 独立插件安装器
#
# 只装 / 更新 / 卸载 zsh-jj 插件, 不动用户的 zsh 基础环境.
# 自动检测 oh-my-zsh, 若未安装则放到 ~/.zsh-jj 并提示手动 source.
#
# 用法:
#   远程一键:  curl -fsSL https://raw.githubusercontent.com/gycog/zsh-jj/main/install-plugin.sh | bash
#   本地执行:  bash install-plugin.sh [--update|--uninstall] [--help]
#
# 环境变量:
#   GH_PROXY       下载代理前缀 (如 "https://ghfast.top/")
#   ZSH_JJ_DIR     覆盖默认安装目录
#   ZSH_JJ_BRANCH  克隆分支/tag (默认 main)
#
# Exit codes: 0=成功 1=参数错误 2=依赖缺失 3=安装/更新失败

set -euo pipefail

REPO="gycog/zsh-jj"
DEFAULT_BRANCH="${ZSH_JJ_BRANCH:-main}"
GH_PROXY="${GH_PROXY:-}"

# ---------- 日志 ----------
if [[ -t 1 ]]; then
    C_RED=$'\033[1;31m'; C_GREEN=$'\033[1;32m'
    C_YELLOW=$'\033[1;33m'; C_BLUE=$'\033[1;34m'
    C_CYAN=$'\033[1;36m'; C_RESET=$'\033[0m'
else
    C_RED=''; C_GREEN=''; C_YELLOW=''; C_BLUE=''; C_CYAN=''; C_RESET=''
fi
log_info() { printf '%s[i]%s %s\n' "$C_BLUE"   "$C_RESET" "$*"; }
log_ok()   { printf '%s[✓]%s %s\n' "$C_GREEN"  "$C_RESET" "$*"; }
log_warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*" >&2; }
log_err()  { printf '%s[✗]%s %s\n' "$C_RED"    "$C_RESET" "$*" >&2; }

# ---------- 工具 ----------
gh_url() {
    if [[ -n "$GH_PROXY" ]]; then
        printf '%s/%s' "${GH_PROXY%/}" "$1"
    else
        printf '%s' "$1"
    fi
}

check_deps() {
    local missing=()
    local bin
    for bin in git zsh; do
        command -v "$bin" >/dev/null 2>&1 || missing+=("$bin")
    done
    if (( ${#missing[@]} > 0 )); then
        log_err "缺少依赖: ${missing[*]}"
        log_info "Debian/Ubuntu: sudo apt install -y ${missing[*]}"
        log_info "macOS (brew) : brew install ${missing[*]}"
        exit 2
    fi
}

detect_target() {
    if [[ -n "${ZSH_JJ_DIR:-}" ]]; then
        printf '%s\n' "$ZSH_JJ_DIR"
        return
    fi
    local omz_custom="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    if [[ -d "$omz_custom/plugins" ]]; then
        printf '%s\n' "$omz_custom/plugins/zsh-jj"
    else
        printf '%s\n' "$HOME/.zsh-jj"
    fi
}

is_omz_target() {
    [[ "$1" == *"/.oh-my-zsh/"* ]] || [[ "$1" == *"/oh-my-zsh/"* ]]
}

# ---------- 动作 ----------
install_plugin() {
    local target="$1"
    local url
    url="$(gh_url "https://github.com/${REPO}.git")"

    if [[ -d "$target/.git" ]]; then
        log_info "检测到已安装, 执行更新: $target"
        if ! git -C "$target" fetch --depth=1 origin "$DEFAULT_BRANCH"; then
            log_err "fetch 失败 (可尝试设置 GH_PROXY)"
            exit 3
        fi
        git -C "$target" reset --hard "origin/$DEFAULT_BRANCH"
        log_ok "已更新到最新版本"
    else
        log_info "克隆 zsh-jj 到: $target"
        mkdir -p "$(dirname "$target")"
        if ! git clone --depth=1 --branch "$DEFAULT_BRANCH" "$url" "$target"; then
            log_err "克隆失败 (可尝试设置 GH_PROXY)"
            exit 3
        fi
        log_ok "已安装到 $target"
    fi

    local version="unknown"
    [[ -r "$target/VERSION" ]] && version="$(<"$target/VERSION")"
    log_info "当前版本: $version"
}

suggest_integration() {
    local target="$1"
    echo
    if is_omz_target "$target"; then
        cat <<EOF
${C_CYAN}检测到 Oh-My-Zsh, 启用步骤:${C_RESET}

  1. 编辑 ~/.zshrc, 在 plugins=(...) 里加入 ${C_GREEN}zsh-jj${C_RESET}

        plugins=(git ... zsh-jj)

  2. 执行 ${C_YELLOW}exec zsh${C_RESET} 或 ${C_YELLOW}source ~/.zshrc${C_RESET}
EOF
    else
        cat <<EOF
${C_CYAN}未检测到 Oh-My-Zsh, 使用手动 source 方式:${C_RESET}

  1. 在 ~/.zshrc 末尾加入:

        ${C_GREEN}source $target/zsh-jj.plugin.zsh${C_RESET}

  2. 执行 ${C_YELLOW}exec zsh${C_RESET} 或 ${C_YELLOW}source ~/.zshrc${C_RESET}
EOF
    fi
    cat <<EOF

使用 zinit / antigen / zplug 的用户无需本脚本, 直接:
  ${C_GREEN}zinit load gycog/zsh-jj${C_RESET}
  ${C_GREEN}antigen bundle gycog/zsh-jj${C_RESET}

EOF
}

uninstall_plugin() {
    local target="$1"
    if [[ ! -d "$target" ]]; then
        log_warn "未找到安装目录: $target"
        return
    fi
    if [[ ! -d "$target/.git" ]] || ! git -C "$target" remote get-url origin 2>/dev/null | grep -q "$REPO"; then
        log_err "目录存在但不像是 zsh-jj 安装: $target"
        log_err "请手动确认后删除"
        exit 3
    fi
    rm -rf "$target"
    log_ok "已卸载: $target"
    log_warn "请手动从 ~/.zshrc 里移除相关 source / plugins 条目"
}

show_help() {
    cat <<'EOF'
zsh-jj 插件安装器

用法:
  install-plugin.sh [选项]

选项:
  (无参数)        默认: 安装或更新到最新版本
  --update        等价于默认 (显式表达意图)
  --uninstall     卸载插件 (不会改 ~/.zshrc)
  -h, --help      显示本帮助

环境变量:
  GH_PROXY        GitHub 下载代理, 例如 "https://ghfast.top/"
  ZSH_JJ_DIR      自定义安装目录 (覆盖 oh-my-zsh 自动检测)
  ZSH_JJ_BRANCH   指定分支或 tag, 默认 "main"

默认安装位置:
  - 检测到 Oh-My-Zsh: $ZSH_CUSTOM/plugins/zsh-jj
  - 否则            : $HOME/.zsh-jj

示例:
  # 大陆网络加速
  GH_PROXY="https://ghfast.top/" bash install-plugin.sh

  # 安装到自定义目录
  ZSH_JJ_DIR="$HOME/dotfiles/zsh-jj" bash install-plugin.sh

  # 锁定指定 tag
  ZSH_JJ_BRANCH="v0.2.0" bash install-plugin.sh
EOF
}

# ---------- 主入口 ----------
main() {
    local action="install"
    while (( $# > 0 )); do
        case "$1" in
            --update|--upgrade) action="install" ;;
            --uninstall|--remove) action="uninstall" ;;
            -h|--help) show_help; exit 0 ;;
            *) log_err "未知参数: $1"; show_help; exit 1 ;;
        esac
        shift
    done

    check_deps
    local target
    target="$(detect_target)"

    case "$action" in
        install)
            install_plugin "$target"
            suggest_integration "$target"
            ;;
        uninstall)
            uninstall_plugin "$target"
            ;;
    esac
}

main "$@"
