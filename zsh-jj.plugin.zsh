#
# zsh-jj — Jujutsu (jj) VCS workflow plugin for Zsh
#
# Homepage: https://github.com/gycog/zsh-jj
# Upstream: https://github.com/jj-vcs/jj
# License : MIT
#
# 兼容加载方式:
#   - oh-my-zsh : 放到 $ZSH_CUSTOM/plugins/zsh-jj 并启用
#   - zinit     : zinit load gycog/zsh-jj
#   - antigen   : antigen bundle gycog/zsh-jj
#   - 手动 source: source /path/to/zsh-jj/zsh-jj.plugin.zsh
#

# ------------------------------------------------------------------
# 0. 定位插件自身目录 (支持任意路径加载, zinit 官方推荐写法)
# ------------------------------------------------------------------
0="${${ZERO:-${0:#$ZSH_ARGZERO}}:-${(%):-%N}}"
0="${${(M)0:#/*}:-$PWD/$0}"

typeset -g ZSH_JJ_PLUGIN_DIR="${0:A:h}"

# 版本号从 VERSION 文件读取 (CI 发布时只需更新这一个文件)
if [[ -r "$ZSH_JJ_PLUGIN_DIR/VERSION" ]]; then
    typeset -g ZSH_JJ_VERSION="$(<"$ZSH_JJ_PLUGIN_DIR/VERSION")"
else
    typeset -g ZSH_JJ_VERSION="0.0.0-dev"
fi

# ------------------------------------------------------------------
# 1. 默认配置 (用户可在 source 之前通过 export 覆盖)
# ------------------------------------------------------------------
: ${ZSH_JJ_SEARCH_MAXDEPTH:=5}
: ${ZSH_JJ_DEV_BOOKMARKS:="Dev dev main master"}
: ${ZSH_JJ_DISABLE_ALIASES:=0}
: ${ZSH_JJ_DISABLE_JJ_COMPLETION:=0}

# jj 二进制自管理: 由 tools/fetch-jj.sh 维护, 由 j-upgrade 触发
: ${ZSH_JJ_JJ_DIR:="${XDG_DATA_HOME:-$HOME/.local/share}/zsh-jj"}
: ${ZSH_JJ_UPGRADE_INTERVAL_DAYS:=7}
: ${ZSH_JJ_DISABLE_AUTO_UPGRADE:=0}

# ------------------------------------------------------------------
# 2. 把插件自管理的 jj/bin 加到 PATH 前面 (若存在)
#    这样哪怕用户没有系统 jj, 只要跑过一次 j-upgrade 就立即可用
# ------------------------------------------------------------------
if [[ -d "$ZSH_JJ_JJ_DIR/bin" ]]; then
    if [[ ":$PATH:" != *":$ZSH_JJ_JJ_DIR/bin:"* ]]; then
        path=("$ZSH_JJ_JJ_DIR/bin" $path)
    fi
fi

# ------------------------------------------------------------------
# 3. 注册 autoload 函数目录 & 插件内置补全目录
# ------------------------------------------------------------------
fpath=("$ZSH_JJ_PLUGIN_DIR/functions" "$ZSH_JJ_PLUGIN_DIR/completions" $fpath)

autoload -Uz \
    jb jr \
    j-amend j-wip j-ff \
    j-init-all j-check j-sync \
    j-upgrade

# ------------------------------------------------------------------
# 3.5 依赖探测 + 懒检查
#     - 没装 jj: 引导用户跑 j-upgrade (不阻塞加载)
#     - 装了 jj: 距离上次检查超过 ZSH_JJ_UPGRADE_INTERVAL_DAYS 天时,
#       后台异步做一次 j-upgrade (静默自动升级, 用户无感知)
# ------------------------------------------------------------------
if (( ! $+commands[jj] )); then
    print -r -- "[zsh-jj] 未检测到 jj, 运行 \`j-upgrade\` 会下载最新版到 $ZSH_JJ_JJ_DIR/bin/jj" >&2
elif [[ "$ZSH_JJ_DISABLE_AUTO_UPGRADE" != "1" ]]; then
    _zj_state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/zsh-jj"
    _zj_stamp="$_zj_state_dir/last-upgrade-check"
    _zj_should_check=1
    if [[ -f "$_zj_stamp" ]]; then
        # 距离上次检查小于 ZSH_JJ_UPGRADE_INTERVAL_DAYS 天则跳过
        if (( $(date +%s) - $(stat -c %Y "$_zj_stamp" 2>/dev/null \
                              || stat -f %m "$_zj_stamp" 2>/dev/null \
                              || echo 0) < ZSH_JJ_UPGRADE_INTERVAL_DAYS * 86400 )); then
            _zj_should_check=0
        fi
    fi
    if (( _zj_should_check )); then
        mkdir -p "$_zj_state_dir" 2>/dev/null
        : >| "$_zj_stamp"
        # 异步静默升级, 输出写日志, 不阻塞 shell 启动
        {
            j-upgrade --quiet >"$_zj_state_dir/last-upgrade.log" 2>&1
        } &!
    fi
    unset _zj_state_dir _zj_stamp _zj_should_check
fi

# ------------------------------------------------------------------
# 4. 集成 jj 官方 zsh 补全 (缓存到 XDG_CACHE_HOME)
#    - 只在首次、或 jj 二进制比缓存新时重新生成
#    - 生成失败不影响插件其它功能
#    - 可通过 ZSH_JJ_DISABLE_JJ_COMPLETION=1 关闭
# ------------------------------------------------------------------
if (( $+commands[jj] )) && [[ "$ZSH_JJ_DISABLE_JJ_COMPLETION" != "1" ]]; then
    _zj_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/zsh-jj"
    _zj_comp_file="$_zj_cache_dir/_jj"

    if [[ ! -s "$_zj_comp_file" ]] || [[ $commands[jj] -nt "$_zj_comp_file" ]]; then
        mkdir -p "$_zj_cache_dir" 2>/dev/null
        # 先尝试新版子命令形式, 失败再退回旧版 flag 形式
        if ! jj util completion zsh >"$_zj_comp_file" 2>/dev/null; then
            if ! jj util completion --zsh >"$_zj_comp_file" 2>/dev/null; then
                rm -f "$_zj_comp_file"
            fi
        fi
    fi

    [[ -s "$_zj_comp_file" ]] && fpath=("$_zj_cache_dir" $fpath)
    unset _zj_cache_dir _zj_comp_file
fi

# ------------------------------------------------------------------
# 5. 为插件自定义函数绑定 bookmark 补全
# ------------------------------------------------------------------
if (( $+functions[compdef] )); then
    compdef _jb jb j-ff 2>/dev/null
fi

# ------------------------------------------------------------------
# 6. 别名 (可通过 ZSH_JJ_DISABLE_ALIASES=1 全部禁用)
#    注意: alias 在 zsh 里会自动跟随底层命令的补全, 只要 _jj 已加载,
#          jbl / jpn / jsh 等 alias 也会自动得到参数级补全
# ------------------------------------------------------------------
if [[ "$ZSH_JJ_DISABLE_ALIASES" != "1" ]]; then
    # --- 查询 ---
    alias jl='jj log -r "all()" --limit 10'
    alias jlp='jj log -p'
    alias jls='jj log --stat'
    alias jla='jj log -r "all()"'
    alias js='jj st'
    alias jv='jj diff'
    alias jvs='jj diff --stat'
    alias jsh='jj show'
    alias jfl='jj files'
    alias jop='jj op log'
    alias jev='jj evolog'

    # --- 改动编辑 ---
    alias jn='jj new'
    alias je='jj edit'
    alias jd='jj describe -m'
    alias ja='jj abandon'
    alias ju='jj undo'
    alias jsq='jj squash'
    alias jsp='jj split'
    alias jre='jj restore'
    alias jrs='jj resolve'
    alias jdup='jj duplicate'
    alias jbo='jj backout'

    # --- 导航 ---
    alias jnx='jj next'
    alias jpv='jj prev'

    # --- Bookmark (书签) ---
    alias jbl='jj bookmark list'
    alias jbla='jj bookmark list --all'
    alias jbc='jj bookmark create'
    alias jbm='jj bookmark move'
    alias jbs='jj bookmark set'
    alias jbd='jj bookmark delete'
    alias jbf='jj bookmark forget'
    alias jbt='jj bookmark track'

    # --- Git 远程 ---
    alias jf='jj git fetch'
    alias jfa='jj git fetch --all-remotes'
    alias jp='jj git push'
    alias jpn='jj git push --allow-new'
    alias jpa='jj git push --all'
    alias jgc='jj git clone'
fi
