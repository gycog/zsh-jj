# zsh-jj

A Zsh plugin that turns [Jujutsu (jj)](https://github.com/jj-vcs/jj) into a daily-driver workflow: 短 alias、智能分支切换、批量 colocate 管理、bookmark Tab 补全。

[![CI](https://github.com/gycog/zsh-jj/actions/workflows/ci.yml/badge.svg)](https://github.com/gycog/zsh-jj/actions/workflows/ci.yml)
[![Release](https://img.shields.io/github/v/release/gycog/zsh-jj?sort=semver)](https://github.com/gycog/zsh-jj/releases)
[![License](https://img.shields.io/badge/license-MIT-blue)](./LICENSE)

---

## 特性

- **40+ 个短别名** 覆盖 jj 常用命令：查询 / 编辑 / 导航 / bookmark / git 五类，双字母为主
- **jj 官方 zsh 补全自动集成**：首次加载时缓存到 `$XDG_CACHE_HOME/zsh-jj/_jj`，之后 `jj <Tab>`、`jp <Tab>`、`jbl <Tab>` 全部命令和选项都能补全
- **自研高频函数**：
  - `jb <关键字>` —— 大小写不敏感地查找 bookmark（本地优先，fallback 远程），匹配后自动 `jj new`
  - `jr` —— rebase 到主干，目标按 `ZSH_JJ_DEV_BOOKMARKS` 的 coalesce 顺序自动选择
  - `j-amend [描述]` —— 当前改动压入父 commit，类似 `git commit --amend`
  - `j-wip <描述>` —— 一步 describe + new，类似 `git commit -m` 并进入下一工作区
  - `j-ff <bookmark> [rev]` —— 快进 bookmark 到指定 revision（默认 `@-`）
  - `j-init-all` / `j-check` / `j-sync` —— 批量管理多个 jj/git 仓库
- **bookmark 智能 Tab**：`jb <Tab>` 和 `j-ff <Tab>` 从 `jj bookmark list --all` 实时补全分支名
- **标准 autoload 结构**：启动零开销，兼容 oh-my-zsh / zinit / antigen / 手动 source
- **全量可配置**：4 个环境变量，可一键禁用别名或禁用补全集成

---

## 安装

### 一键脚本（推荐）

自动识别你是否有 Oh-My-Zsh，相应地放到正确位置并给出启用提示：

```bash
curl -fsSL https://raw.githubusercontent.com/gycog/zsh-jj/main/install-plugin.sh | bash
```

或本地执行：`bash install-plugin.sh [--update|--uninstall|--help]`

脚本支持以下环境变量：

| 变量             | 作用                                                 |
| ---------------- | ---------------------------------------------------- |
| `GH_PROXY`       | GitHub 下载代理，如 `"https://ghfast.top/"`           |
| `ZSH_JJ_DIR`     | 自定义安装目录（覆盖 oh-my-zsh 自动检测）            |
| `ZSH_JJ_BRANCH`  | 克隆的分支或 tag，默认 `main`；锁定版本用 `v0.2.0`    |

### Oh-My-Zsh（手动）

```bash
git clone https://github.com/gycog/zsh-jj \
    "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-jj"
```

然后在 `~/.zshrc` 的 `plugins=(...)` 里加入 `zsh-jj`：

```zsh
plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-jj)
```

重启 shell 或 `source ~/.zshrc` 生效。

### Zinit

```zsh
zinit load gycog/zsh-jj
```

### Antigen

```zsh
antigen bundle gycog/zsh-jj
```

### 纯手工 source

```zsh
git clone https://github.com/gycog/zsh-jj ~/.zsh-jj
echo 'source ~/.zsh-jj/zsh-jj.plugin.zsh' >> ~/.zshrc
```

### 前置要求

- `zsh` 5.8+
- `jj` 在 `PATH` 中（参考 [Jujutsu 安装指引](https://jj-vcs.github.io/jj/latest/install-and-setup/)）

---

## 命令速查

### 别名（可通过 `ZSH_JJ_DISABLE_ALIASES=1` 全部禁用）

#### 查询

| 别名  | 展开命令                         | 用途                    |
| ----- | -------------------------------- | ----------------------- |
| `jl`  | `jj log -r "all()" --limit 10`   | 最近 10 条改动          |
| `jlp` | `jj log -p`                      | 日志 + patch            |
| `jls` | `jj log --stat`                  | 日志 + 文件统计         |
| `jla` | `jj log -r "all()"`              | 所有 revision           |
| `js`  | `jj st`                          | 工作副本状态            |
| `jv`  | `jj diff`                        | 查看 diff               |
| `jvs` | `jj diff --stat`                 | diff 文件统计           |
| `jsh` | `jj show`                        | 查看指定 revision       |
| `jfl` | `jj files`                       | 当前改动的文件列表      |
| `jop` | `jj op log`                      | 操作日志（repo 级 undo 源）|
| `jev` | `jj evolog`                      | 单个 change 的演化日志  |

#### 编辑 / 改动

| 别名   | 展开命令            | 用途                                  |
| ------ | ------------------- | ------------------------------------- |
| `jn`   | `jj new`            | 新建改动                              |
| `je`   | `jj edit`           | 切到某个 revision 作为工作副本        |
| `jd`   | `jj describe -m`    | 写 / 改 commit message                |
| `ja`   | `jj abandon`        | 扔掉不想要的改动                      |
| `ju`   | `jj undo`           | 撤销上一次操作（操作级 undo）         |
| `jsq`  | `jj squash`         | 把当前改动压入父（≈ git commit --amend）|
| `jsp`  | `jj split`          | 拆分当前 commit                       |
| `jre`  | `jj restore`        | 从其它 revision 还原文件              |
| `jrs`  | `jj resolve`        | 解决冲突                              |
| `jdup` | `jj duplicate`      | 复制 commit                           |
| `jbo`  | `jj backout`        | 反向提交                              |

#### 导航

| 别名  | 展开命令   | 用途                  |
| ----- | ---------- | --------------------- |
| `jnx` | `jj next`  | 移到下一个 change     |
| `jpv` | `jj prev`  | 移到上一个 change     |

#### Bookmark（书签）

| 别名   | 展开命令                    | 用途                  |
| ------ | --------------------------- | --------------------- |
| `jbl`  | `jj bookmark list`          | 列出本地 bookmark     |
| `jbla` | `jj bookmark list --all`    | 列出全部（含远程）    |
| `jbc`  | `jj bookmark create`        | 创建 bookmark         |
| `jbm`  | `jj bookmark move`          | 移动 bookmark         |
| `jbs`  | `jj bookmark set`           | 设置 bookmark 到某 revision |
| `jbd`  | `jj bookmark delete`        | 删除 bookmark         |
| `jbf`  | `jj bookmark forget`        | 忘记 bookmark         |
| `jbt`  | `jj bookmark track`         | 跟踪远程 bookmark     |

#### Git 远程

| 别名  | 展开命令                       | 用途                        |
| ----- | ------------------------------ | --------------------------- |
| `jf`  | `jj git fetch`                 | 从远程拉取                  |
| `jfa` | `jj git fetch --all-remotes`   | 从所有远程拉取              |
| `jp`  | `jj git push`                  | 推送到远程                  |
| `jpn` | `jj git push --allow-new`      | 推送并允许新 bookmark（常用）|
| `jpa` | `jj git push --all`            | 推送所有 bookmark           |
| `jgc` | `jj git clone`                 | 克隆 git 仓库为 jj 仓库     |

### 函数

| 函数                    | 说明                                                                 |
| ----------------------- | -------------------------------------------------------------------- |
| `jb <关键字>`            | 在本地+远程 bookmark 里大小写不敏感查找，自动 `jj new`              |
| `jr [参数]`              | rebase 到 `ZSH_JJ_DEV_BOOKMARKS` 里第一个存在的 bookmark             |
| `j-amend [描述]`         | 当前改动压入父 commit，可选顺带改写父的描述                           |
| `j-wip <描述>`           | 一步完成 describe + new（commit 完直接进下一个改动）                  |
| `j-ff <bookmark> [rev]`  | 快进 bookmark 到指定 revision（默认 `@-`）                           |
| `j-init-all`             | 递归扫描 `.git` 仓库，批量 `jj git init --colocate`                   |
| `j-check`                | 递归扫描 `.jj` 仓库，打印有改动的 / 未描述的条目                      |
| `j-sync`                 | 递归扫描 `.jj` 仓库，批量 `jj git fetch`                             |

### 自动补全

**`jj` 官方补全自动集成**（v0.2+）：首次加载插件时会执行一次 `jj util completion zsh` 并缓存到 `${XDG_CACHE_HOME:-~/.cache}/zsh-jj/_jj`。之后：

```text
jj <Tab>            → 列出所有子命令
jj log --<Tab>      → 列出 log 的所有选项
jbl <Tab>           → alias 自动继承 jj 补全，列出 bookmark 参数
jpn <Tab>           → 同上
```

**自研 bookmark 补全**（应用于 `jb` 和 `j-ff`）：

```text
jb d<Tab>           → dev  Dev  develop-feature  ...
j-ff release<Tab>   → release-1.0  release-2.0  ...
```

从 `jj bookmark list --all` 读取，仓库外或非 jj 目录会静默无补全。

> 当 `jj` 二进制升级后，插件会自动重新生成补全缓存（基于 mtime 比较）。
> 如需禁用官方补全集成：`export ZSH_JJ_DISABLE_JJ_COMPLETION=1`。

---

## 配置

所有环境变量都有默认值；在 source 插件之前 `export` 即可生效。

| 变量                           | 默认值                   | 说明                                                 |
| ------------------------------ | ------------------------ | ---------------------------------------------------- |
| `ZSH_JJ_SEARCH_MAXDEPTH`       | `5`                      | `j-init-all / j-check / j-sync` 的 `find` 最大深度   |
| `ZSH_JJ_DEV_BOOKMARKS`         | `"Dev dev main master"`  | `jr` 的 rebase 目标候选（空格分隔，按顺序）          |
| `ZSH_JJ_DISABLE_ALIASES`       | `0`                      | 设为 `1` 则不定义任何短别名（函数仍可用）            |
| `ZSH_JJ_DISABLE_JJ_COMPLETION` | `0`                      | 设为 `1` 则不自动生成 / 注册 `jj` 官方补全           |

示例：

```zsh
# 团队主干叫 trunk，扫描 3 层够用
export ZSH_JJ_SEARCH_MAXDEPTH=3
export ZSH_JJ_DEV_BOOKMARKS="trunk main"

# 某个短别名和你已有的配置冲突？可以选择性 unalias（推荐）
# 在 ~/.zshrc 里 zsh-jj 加载之后加一行：
unalias jbo 2>/dev/null   # 比如你已经把 jbo 用于别的工具
```

---

## 目录结构

```text
zsh-jj/
├── zsh-jj.plugin.zsh     # 入口：fpath 注册 + autoload + 别名
├── functions/            # autoload 函数（无扩展名，zsh 约定）
│   ├── jb                # bookmark 智能切换
│   ├── jr                # rebase 到主干（配置驱动）
│   ├── j-amend           # 压入父 commit
│   ├── j-wip             # describe + new
│   ├── j-ff              # 快进 bookmark
│   ├── j-init-all        # 批量 colocate 初始化
│   ├── j-check           # 批量查状态
│   └── j-sync            # 批量 fetch
├── completions/          # zsh 补全
│   └── _jb               # bookmark 动态补全（jb / j-ff 共用）
├── .github/workflows/    # CI / Release
│   ├── ci.yml            # zsh 语法 + 烟雾加载 + shellcheck + 版本校验
│   └── release.yml       # 推 v* tag 时自动发 Release
├── install-plugin.sh     # 独立安装器（install / update / uninstall）
├── VERSION               # 单一版本号来源，CI 会校验与 tag 一致
├── LICENSE
└── README.md
```

---

## 发布流程（给维护者）

版本号的单一来源是根目录 `VERSION` 文件，插件加载时动态读取。发布新版本：

```bash
# 1. 改版本
echo 0.3.0 > VERSION
git add VERSION
git commit -m "Release v0.3.0"

# 2. 打 tag
git tag v0.3.0
git push origin main --tags
```

推送后：

- **CI workflow** 会校验 `VERSION` 文件为合法 semver，并做 zsh 语法、烟雾加载、shellcheck
- **Release workflow** 会校验 tag (`v0.3.0`) 与 `VERSION` 文件 (`0.3.0`) 一致，然后自动创建 GitHub Release（带自动生成的 changelog）
- tag 里带 `-` 的（如 `v0.3.0-rc1`）会自动标为 pre-release

---

## License

[MIT](./LICENSE)

上游项目 [jj-vcs/jj](https://github.com/jj-vcs/jj) 采用 Apache-2.0。
