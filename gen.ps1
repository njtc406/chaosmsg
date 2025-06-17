# 打包proto消息脚本
Write-Host "=================开始打包proto消息====================="
Write-Host ""

# 设置目录路径
$currentDir = Get-Location
$protoDir = Join-Path $currentDir "proto"
$outDir = Join-Path $currentDir "output"
$serverOutputDir = Join-Path $outDir "server"
$clientOutputDir = Join-Path $outDir "client"
$copyDir = Join-Path $currentDir "..\server\internal\msg"
$srcDir = Join-Path $protoDir "src"
$scriptsDir = Join-Path $protoDir "scripts"
$libBinDir = Join-Path $protoDir "lib\node_modules\.bin"

# 客户端消息文件目录(客户端只会打包这个目录下面的proto文件)
$clientMsgExceptDirName = "internal_msg"

# 创建必要的目录
if (-not (Test-Path $outDir)) {
    Write-Host "输出目录不存在,创建目录..."
    New-Item -ItemType Directory -Path $outDir | Out-Null
}

if (-not (Test-Path $serverOutputDir)) {
    Write-Host "服务器输出目录不存在,创建目录..."
    New-Item -ItemType Directory -Path $serverOutputDir | Out-Null
}

if (-not (Test-Path $clientOutputDir)) {
    Write-Host "客户端输出目录不存在,创建目录..."
    New-Item -ItemType Directory -Path $clientOutputDir | Out-Null
}

# 获取所有包含proto文件的目录
$protoDirs = Get-ChildItem -Path $srcDir -Directory

foreach ($dir in $protoDirs) {
    $dirName = $dir.Name
    $protoFiles = Get-ChildItem -Path $dir.FullName -Filter "*.proto"
    
    if ($protoFiles.Count -eq 0) {
        Write-Host "INFO: [$dirName]目录下没有proto文件,跳过"
        continue
    }
    
    Write-Host "INFO: ====== 开始打包--[$dirName]--中的proto文件"
    
    # 创建服务器输出子目录
    $serverSubDir = Join-Path $serverOutputDir $dirName
    if (-not (Test-Path $serverSubDir)) {
        New-Item -ItemType Directory -Path $serverSubDir | Out-Null
    }
    
    # 编译proto文件 - 逐个文件处理
    $success = $true
    foreach ($protoFile in $protoFiles) {
        $protocArgs = @(
            "-I=$srcDir",
            "--plugin=protoc-gen-go=`"$(Join-Path $scriptsDir 'protoc-gen-go.exe')`"",
            "--plugin=protoc-gen-go-grpc=`"$(Join-Path $scriptsDir 'protoc-gen-go-grpc.exe')`"",
            "--go_out=paths=source_relative:$serverSubDir",
            "--go-grpc_out=paths=source_relative:$serverSubDir",
            $protoFile.FullName
        )

        $protocProcess = Start-Process -FilePath (Join-Path $scriptsDir "protoc.exe") `
            -ArgumentList $protocArgs `
            -NoNewWindow -Wait -PassThru

        if ($protocProcess.ExitCode -ne 0) {
            Write-Host "[$($protoFile.Name)]生成服务器pb文件失败" -ForegroundColor Red
            $success = $false
        }
    }

    if (-not $success) {
        Read-Host "按任意键退出..."
        exit 1
    }

    # 检查生成的 .pb.go 文件
    $pbGoFiles = Get-ChildItem -Path $serverSubDir -Filter "*.pb.go"
    if ($pbGoFiles.Count -eq 0) {
        Write-Host "警告: 在 $serverSubDir 中没有找到 .pb.go 文件" -ForegroundColor Yellow
        continue
    }

    # 注入标签 - 逐个文件处理
    $success = $true
    foreach ($pbGoFile in $pbGoFiles) {
        $injectArgs = @(
            "-input=$($pbGoFile.FullName)"
        )

        $injectProcess = Start-Process -FilePath (Join-Path $scriptsDir "protoc-go-inject-tag.exe") `
            -ArgumentList $injectArgs `
            -NoNewWindow -Wait -PassThru

        if ($injectProcess.ExitCode -ne 0) {
            Write-Host "[$($pbGoFile.Name)]生成服务器pb标签失败" -ForegroundColor Red
            $success = $false
        }
    }

    if (-not $success) {
        Read-Host "按任意键退出..."
        exit 1
    }

    # 处理msg.proto文件
    $msgProtoFile = Join-Path $dir.FullName "msg.proto"
    if (Test-Path $msgProtoFile) {
        $messageGoFile = Join-Path $serverSubDir "message.go"

        $parserArgs = @(
            $msgProtoFile,
            $messageGoFile
        )

        $parserProcess = Start-Process -FilePath (Join-Path $scriptsDir "protoparser.exe") `
            -ArgumentList $parserArgs `
            -NoNewWindow -Wait -PassThru

        if ($parserProcess.ExitCode -ne 0) {
            Write-Host "生成服务器message文件失败" -ForegroundColor Red
            Read-Host "按任意键退出..."
            exit 1
        }

        # 格式化文件
        if (Test-Path $messageGoFile) {
            $gofmtArgs = @(
                "-w",
                $messageGoFile
            )

            $gofmtProcess = Start-Process -FilePath (Join-Path $scriptsDir "gofmt.exe") `
                -ArgumentList $gofmtArgs `
                -NoNewWindow -Wait -PassThru

            if ($gofmtProcess.ExitCode -ne 0) {
                Write-Host "格式化message文件失败" -ForegroundColor Yellow
            }
        } else {
            Write-Host "警告: 未找到 $messageGoFile 文件" -ForegroundColor Yellow
        }
    }
}

# 拷贝到客户端输出目录（排除指定目录）
Write-Host "开始拷贝到客户端输出目录..."
$excludeDirs = @("actor", $clientMsgExceptDirName)
Get-ChildItem -Path $srcDir -Directory | Where-Object {
    $_.Name -notin $excludeDirs
} | ForEach-Object {
    $destDir = Join-Path $clientOutputDir $_.Name
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir | Out-Null
    }
    Copy-Item -Path "$($_.FullName)\*" -Destination $destDir -Recurse -Force
}
Write-Host "拷贝完成"
Write-Host ""

# 拷贝到服务器运行目录
if (Test-Path $copyDir) {
    Write-Host "开始拷贝服务器输出到运行目录..."
    $excludeDirs = @("actor")
    Get-ChildItem -Path $serverOutputDir -Directory | Where-Object {
        $_.Name -notin $excludeDirs
    } | ForEach-Object {
        $destDir = Join-Path $copyDir $_.Name
        if (-not (Test-Path $destDir)) {
            New-Item -ItemType Directory -Path $destDir | Out-Null
        }
        Copy-Item -Path "$($_.FullName)\*" -Destination $destDir -Recurse -Force
    }
    Write-Host "拷贝完成"
}

Write-Host ""
Write-Host "=================proto消息打包完成====================="

Read-Host "按任意键退出..."