#!/bin/bash

echo "================= 开始打包 proto 消息 ====================="
echo

cd ./proto

# 打包后的输出目录
outDir=../output
# 服务器文件目录
server_outputDir="$outDir/server"
# 客户端文件目录
client_outputDir="$outDir/client"
# 客户端消息文件目录 (客户端只会打包这个目录下面的 proto 文件)
client_msg_dir_name="msg"
# 设置一个拷贝目录，将打好的消息自动拷贝到对应的位置，后续再说，现在先不用
copyDir=.

# 源文件目录
src_dir="./src"
# 执行文件目录
scripts_dir="./scripts"

# 检查输出目录是否存在，不存在则创建
if [ ! -d "$outDir" ]; then
    echo "输出目录不存在, 创建目录..."
    mkdir -p "$outDir"
fi

if [ ! -d "$server_outputDir" ]; then
    echo "服务器输出目录不存在, 创建目录..."
    mkdir -p "$server_outputDir"
fi

if [ ! -d "$client_outputDir" ]; then
    echo "客户端输出目录不存在, 创建目录..."
    mkdir -p "$client_outputDir"
fi

# 开启延迟变量扩展（shell 默认会处理变量展开）
for dir in "$src_dir"/*/; do
    if [ -d "$dir" ]; then
        # 直接拼接完整路径
        dirPath=$(pwd)/"$dir"

        # 检查目录是否为空
        if ! ls "$dirPath"/*.proto > /dev/null 2>&1; then
            echo "INFO: [$(basename "$dir")] 目录下没有 proto 文件, 跳过"
        else
            echo "INFO: ====== 开始打包--[$(basename "$dir")]--中的 proto 文件"

            # 创建服务器目录
            if [ ! -d "$server_outputDir/$(basename "$dir")" ]; then
                mkdir -p "$server_outputDir/$(basename "$dir")"
            fi

            # 调用 protoc 生成 Go 文件
            "$scripts_dir/protoc.exe" --plugin=protoc-gen-go="$scripts_dir/protoc-gen-go.exe" --go_out="$server_outputDir/$(basename "$dir")" "$dir"/*.proto

            # 处理 Go 文件
            "$scripts_dir/protoc-go-inject-tag.exe" -input="$server_outputDir/$(basename "$dir")"/*.pb.go

            if [ "$(basename "$dir")" == "$client_msg_dir_name" ]; then
                # 创建客户端目录
                if [ ! -d "$client_outputDir/$(basename "$dir")" ]; then
                    mkdir -p "$client_outputDir/$(basename "$dir")"
                fi

                # 获取相对路径部分，去掉 src 部分
                relative_dir="${dir#"$src_dir/"}"
                relative_dir="${relative_dir%/}"  # 去除尾部的斜杠

                # 调用 protoc 生成 TypeScript 文件
                "$scripts_dir/protoc.exe" -I="$dir" --plugin=protoc-gen-ts="../../lib/node_modules/.bin/protoc-gen-ts.cmd" --ts_out="$client_outputDir/$(basename "$dir")" "$dir"/*.proto
            fi
        fi
    fi
done

echo
echo "================= proto 消息打包完成 ====================="

