#!/bin/bash

# VS Code Profiles 审计工具
# 功能:
#   check - 全量审计 [本地 VS Code 实时配置] vs [仓库备份]
#   sync  - 全量同步本地所有 Profile 到仓库

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

VSCODE_USER_DIR="$HOME/Library/Application Support/Code/User"
VSCODE_STORAGE="$VSCODE_USER_DIR/globalStorage/storage.json"

# 检查依赖
for cmd in jq code node; do
    command -v $cmd >/dev/null 2>&1 || { echo -e "${RED}错误: 需要安装 $cmd${NC}" >&2; exit 1; }
done

# 辅助：解析 JSONC 为标准 JSON
function parse_jsonc() {
    if [ -f "$1" ]; then
        node -e '
            const fs = require("fs");
            let s = fs.readFileSync(process.argv[1], "utf8");
            // Strip single-line comments outside strings
            s = s.replace(/"(?:[^"\\]|\\.)*"|\/\/.*$/gm, (m) => m.startsWith("/") ? "" : m);
            // Strip block comments outside strings
            s = s.replace(/"(?:[^"\\]|\\.)*"|\/\*[\s\S]*?\*\//g, (m) => m.startsWith("/") ? "" : m);
            // Strip trailing commas
            s = s.replace(/,(\s*[}\]])/g, "$1");
            console.log(JSON.stringify(JSON.parse(s)));
        ' "$1"
    else
        echo "{}"
    fi
}

# 获取 Profile 的本地物理路径
function get_profile_base_path() {
    local profile_name="$1"
    if [ "$profile_name" == "Default" ]; then
        echo "$VSCODE_USER_DIR"
    else
        local location=$(jq -r --arg name "$profile_name" '.userDataProfiles[] | select(.name == $name) | .location' "$VSCODE_STORAGE" 2>/dev/null)
        if [ -n "$location" ]; then
            echo "$VSCODE_USER_DIR/profiles/$location"
        else
            echo ""
        fi
    fi
}

function check_profile() {
    local dir_name="$1"
    local config_dir="config/$dir_name"
    local profile_name=$([ "$dir_name" == "default" ] && echo "Default" || echo "$dir_name")

    # 定位本地物理路径
    local local_base_path=$(get_profile_base_path "$profile_name")
    if [ -z "$local_base_path" ]; then
        echo -e "${RED}无法定位 Profile '$profile_name' 的本地路径${NC}"; return 1
    fi

    echo -e "${BOLD}$profile_name:${NC}"

    # 1. 扩展比对 (Local vs Repo)
    echo -n -e "  [扩展插件]: "
    local local_exts=$(code --list-extensions --profile "$profile_name" 2>/dev/null | tr '[:upper:]' '[:lower:]' | sort)
    local repo_exts=$(jq -r '.[]' "$config_dir/extensions.json" | tr '[:upper:]' '[:lower:]' | sort)
    local missing_exts=$(comm -13 <(echo "$local_exts") <(echo "$repo_exts"))
    local extra_exts=$(comm -23 <(echo "$local_exts") <(echo "$repo_exts"))

    if [ -z "$missing_exts" ] && [ -z "$extra_exts" ]; then
        echo -e "${GREEN}一致${NC}"
    else
        echo -e "${RED}发现差异${NC}"
        [ -n "$missing_exts" ] && echo "$missing_exts" | sed 's/^/    - [未安装] /'
        [ -n "$extra_exts" ] && echo "$extra_exts" | sed 's/^/    - [未备份] /'
    fi

    # 2. 设置比对 (Local vs Repo)
    echo -n -e "  [Settings]: "
    local local_settings="$local_base_path/settings.json"
    if [ -f "$local_settings" ]; then
        local repo_json=$(parse_jsonc "$config_dir/settings.json" | jq -S .)
        local local_json=$(parse_jsonc "$local_settings" | jq -S .)
        local diff_keys=$(jq -n --argjson a "$repo_json" --argjson b "$local_json" '
            (($b | keys) - ($a | keys)) as $added |
            (($a | keys) - ($b | keys)) as $removed |
            ([($a | keys[]) as $k | select($a[$k] != $b[$k]) | $k] - $added - $removed) as $changed |
            {added: $added, removed: $removed, changed: $changed}')
        local has_diff=$(echo "$diff_keys" | jq 'any(.[]; length > 0)')
        if [ "$has_diff" == "false" ]; then echo -e "${GREEN}一致${NC}"; else
            echo -e "${RED}偏离备份${NC}"
            echo "$diff_keys" | jq -r '.added[] // empty' | while read -r k; do echo -e "    ${GREEN}+ $k${NC}"; done
            echo "$diff_keys" | jq -r '.removed[] // empty' | while read -r k; do echo -e "    ${RED}- $k${NC}"; done
            echo "$diff_keys" | jq -r '.changed[] // empty' | while read -r k; do echo -e "    ${YELLOW}~ $k${NC}"; done
        fi
    else
        echo -e "${YELLOW}未发现本地设置文件${NC}"
    fi

    # 3. MCP 比对 (Local vs Repo)
    echo -n -e "  [MCP 配置]: "
    local local_mcp="$local_base_path/mcp.json"
    if [ -f "$local_mcp" ]; then
        local repo_json=$(parse_jsonc "$config_dir/mcp.json" | jq -S .)
        local local_json=$(parse_jsonc "$local_mcp" | jq -S .)
        local diff_keys=$(jq -n --argjson a "$repo_json" --argjson b "$local_json" '
            (($b | keys) - ($a | keys)) as $added |
            (($a | keys) - ($b | keys)) as $removed |
            ([($a | keys[]) as $k | select($a[$k] != $b[$k]) | $k] - $added - $removed) as $changed |
            {added: $added, removed: $removed, changed: $changed}')
        local has_diff=$(echo "$diff_keys" | jq 'any(.[]; length > 0)')
        if [ "$has_diff" == "false" ]; then echo -e "${GREEN}一致${NC}"; else
            echo -e "${RED}偏离备份${NC}"
            echo "$diff_keys" | jq -r '.added[] // empty' | while read -r k; do echo -e "    ${GREEN}+ $k${NC}"; done
            echo "$diff_keys" | jq -r '.removed[] // empty' | while read -r k; do echo -e "    ${RED}- $k${NC}"; done
            echo "$diff_keys" | jq -r '.changed[] // empty' | while read -r k; do echo -e "    ${YELLOW}~ $k${NC}"; done
        fi
    elif [ -f "$config_dir/mcp.json" ]; then
        echo -e "${RED}本地缺失 mcp.json${NC}"
    else
        echo -e "${GREEN}均未配置 (跳过)${NC}"
    fi
}

function select_and_check() {
    local profiles=($(ls -d config/*/ | xargs -n 1 basename))
    echo -e "${BLUE}${BOLD}选择要审计的 Profile:${NC}"
    for i in "${!profiles[@]}"; do echo -e "  $((i+1))) ${profiles[$i]}"; done
    echo -e "  0) 全部审计"

    read -p "选择 (0-${#profiles[@]}): " choice

    if [[ "$choice" == "0" ]]; then
        echo -e "${BLUE}${BOLD}===> 开始全量审计${NC}"
        for d in config/*/; do
            check_profile "$(basename "$d")"
        done
    elif [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#profiles[@]} ]; then
        check_profile "${profiles[$((choice-1))]}"
    else
        echo -e "${RED}输入无效。${NC}"; return 1
    fi
}

function sync_profile() {
    local dir_name="$1"
    local d="config/$dir_name"
    local profile_name=$([ "$dir_name" == "default" ] && echo "Default" || echo "$dir_name")
    echo -e "${BOLD}$profile_name:${NC}"

    # 扩展
    echo -n -e "  [扩展插件]: "
    local output=$(code --list-extensions --profile "$profile_name" 2>&1)
    if [ $? -ne 0 ] || [[ "$output" == *"not found"* ]]; then
        echo -e "${YELLOW}[SKIP]${NC}"
        return 1
    fi
    echo "$output" | jq -R . | jq -s . > "$d/extensions.json"
    echo -e "${GREEN}[DONE]${NC}"

    # 定位本地路径
    local local_base_path=$(get_profile_base_path "$profile_name")
    if [ -z "$local_base_path" ]; then
        echo -e "  ${YELLOW}无法定位本地路径，跳过 settings/mcp${NC}"
        return 1
    fi

    # Settings
    echo -n -e "  [Settings]: "
    if [ -f "$local_base_path/settings.json" ]; then
        cp "$local_base_path/settings.json" "$d/settings.json"
        echo -e "${GREEN}[DONE]${NC}"
    else
        echo -e "${YELLOW}[SKIP] 本地无 settings.json${NC}"
    fi

    # MCP
    echo -n -e "  [MCP 配置]: "
    if [ -f "$local_base_path/mcp.json" ]; then
        cp "$local_base_path/mcp.json" "$d/mcp.json"
        echo -e "${GREEN}[DONE]${NC}"
    else
        echo -e "${YELLOW}[SKIP] 本地无 mcp.json${NC}"
    fi
}

function select_and_sync() {
    local profiles=($(ls -d config/*/ | xargs -n 1 basename))
    echo -e "${BLUE}${BOLD}选择要同步的 Profile:${NC}"
    for i in "${!profiles[@]}"; do echo -e "  $((i+1))) ${profiles[$i]}"; done
    echo -e "  0) 全部同步"

    read -p "选择 (0-${#profiles[@]}): " choice

    if [[ "$choice" == "0" ]]; then
        echo -e "${BLUE}${BOLD}===> 开始全量同步到仓库${NC}"
        for d in config/*/; do
            sync_profile "$(basename "$d")"
        done
    elif [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#profiles[@]} ]; then
        sync_profile "${profiles[$((choice-1))]}"
    else
        echo -e "${RED}输入无效。${NC}"; return 1
    fi
}

case "$1" in
    check) select_and_check ;;
    sync) select_and_sync ;;
    *) echo "用法: $0 {check|sync}"; exit 1 ;;
esac
