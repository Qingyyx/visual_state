#!/bin/bash
script_dir="your/path"
target=your/path/state/self.md

# 功能1：执行 git add . 和 git commit --allow-empty -am "当前日期，当前时间"
function commit_changes() {
    current_date=$(date +"%Y-%m-%d")
    current_time=$(date +"%H:%M:%S")
    cd "$script_dir" || exit
    git add .
    git commit --allow-empty -am "$current_date, $current_time"
    echo "提交完成：$current_date, $current_time"
}

# 功能2：合并当日日志
function merge_logs() {
    cd "$script_dir" || exit

    if [ $# -eq 0 ]; then
        current_date=$(date +"%Y-%m-%d")
    elif [ $# -eq 1 ]; then
        current_date=$(date +"%Y-%m-")$1
    elif [ $# -eq 2 ]; then
        current_date=$(date +"%Y-")$1-$2
    elif [ $# -eq 3 ]; then
        current_date=$1-$2-$3
    else
        echo "用法：merge [日期|月份 日期|年份 月份 日期]"
        return 1
    fi

    date -d "$current_date" >/dev/null 2>&1
    if [ $? -ne 0 ]; then
        echo "日期格式错误，请使用 YYYY-MM-DD 或 MM-DD 或 YYYY-MM 或 YYYY 格式。"
        return 1
    fi

    year=$(echo "$current_date" | cut -d'-' -f1)
    month=$(echo "$current_date" | cut -d'-' -f2)
    day=$(echo "$current_date" | cut -d'-' -f3)

    echo $current_date

    log_output=$(git log --reverse --since="$current_date 00:00:00" --until="$current_date 23:59:59" \
    --pretty=format:"%H %ad" --date=iso)

    echo $log_output

    if [ -z "$log_output" ]; then
        echo "没有找到符合条件的提交记录。"
        return 0
    fi

    target_dir="./$year/$month"
    mkdir -p "$target_dir"
    output_file="$target_dir/$day.md"

    # 清空旧内容
    > "$output_file"


    # 获取当日提交并按时间正序处理
    echo "$log_output" | while IFS= read -r line || [[ -n "$line" ]]; do
        commit_hash=$(echo "$line" | awk '{print $1}')
        commit_time=$(echo "$line" | awk '{print $3}')

        # # 检查文件是否存在并处理
        if git show "$commit_hash:state/self.md" >/dev/null 2>&1; then
            echo -e "\n# $commit_time" >> "$output_file"
            git show "$commit_hash:state/self.md" >> "$output_file"
            echo -e "\n\n" >> "$output_file"
        fi
    done

    echo "日志合并完成，文件保存在 $output_file"
}

function lsc() {
    if [ $# -eq 0 ]; then
        # 如果没有参数，输出整个文件内容
        cat "$target"
        return
    fi

    for state_name in "$@"; do
        state_name=$(echo "$state_name" | tr '[:lower:]' '[:upper:]')
        if grep -q "$state_name" "$target"; then
            # 如果状态存在，输出状态值
            grep "$state_name" "$target"
        else
            echo "The $state_name is not exist"
        fi
    done
}

function set() {
    state_name=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    state_value=$2
    if [ -z "$state_name" ] || [ -z "$state_value" ]; then
        echo "用法：sta set <状态名称> <状态值>"
        return 1
    fi
    # 检查状态名称是否已存在
    if grep -q "\<$state_name\>" "$target"; then
        # 仅修改数值，保留其他格式
        sed -i "s/\($state_name\*\*： *\|$state_name： *\)\([0-9]*\)/\1$state_value/" "$target"
        echo "状态 $state_name 已更新为 $state_value"
    else
        echo "The $state_name is not exist"
    fi
}

function mfy() {
    state_name=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    state_value=$2
    if [ -z "$state_name" ] || [ -z "$state_value" ]; then
        echo "用法：sta mfy <状态名称> <状态值>"
        return 1
    fi


    # 检查状态名称是否已存在
    if grep -q "\<$state_name\>" "$target"; then
        # 提取当前值
        current_value=$(grep "\<$state_name\>" "$target" | sed -E "s/.*$state_name.*：([0-9]+).*/\1/")
        # 计算新值
        new_value=$((current_value + state_value))
        # 更新文件中的值
        sed -i "s/\($state_name\*\*： *\|$state_name： *\)$current_value/\1$new_value/" "$target"
        echo "状态 $state_name 已更新为 $new_value"
    else
        echo "The $state_name is not exist"
    fi
}

function add() {
    state_name=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    state_describetion=$2
    state_value=$3
    state_type=$4
    if [ -z "$state_name" ] || [ -z "$state_value" ]; then
        echo "用法：sta add <状态名称> <状态描述> <状态值> <状态类型>"
        return 1
    fi
    # 检查状态名称是否已存在
    if grep -q "\<$state_name\>" "$target"; then
        echo "The $state_name is exist"
        return 1
    fi

    if [ -z "$state_type" ]; then
        echo "$state_describetion $state_name：$state_value" >> "$target"
        echo "状态 $state_name 已添加，值为 $state_value"
    else
        state_type=$(echo "$state_type" | tr '[:lower:]' '[:upper:]')
        if grep -q "\<$state_type\>" "$target"; then
            sed -i "/\<$state_type\>/a $state_describetion $state_name：$state_value" "$target"
            echo "状态 $state_name 已添加到类型 $state_type 下，值为 $state_value"
        else
            echo "类型 $state_type 不存在"
            return 1
        fi
    fi
    # 添加新状态行
}

function del() {
    state_name=$(echo "$1" | tr '[:lower:]' '[:upper:]')
    if [ -z "$state_name" ]; then
        echo "用法：sta del <状态名称>"
        return 1
    fi
    # 检查状态名称是否已存在
    if grep -q "\<$state_name\>" "$target"; then
        # 删除状态行
        sed -i "/\<$state_name\>/d" "$target"
        echo "状态 $state_name 已删除"
    else
        echo "The $state_name is not exist"
    fi
}

function show() {
    cd "$script_dir" || exit

    python3 ./visualization.py $@

}

# 主函数
function main() {
    case $1 in
        "commit") commit_changes ;;
        "merge") shift; merge_logs $@  ;;
        "ls") shift; lsc "$@" ;;
        "set") set $2 $3 ;; 
        "mfy") mfy $2 $3 ;;
        "add") add $2 $3 $4 $5;;
        "del") del $2;;
        "show") shift; show $@ ;;
        *) echo "用法：sta [commit|merge|ls|set|mfy|add|del|show]" ;;
    esac
}

main "$@"
