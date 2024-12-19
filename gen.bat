@echo off
echo =================开始打包proto消息=====================
echo.

cd .\proto
:: 打包后的输出目录
set outDir=..\output
:: 服务器文件目录
set server_outputDir=%outDir%\server
:: 客户端文件目录
set client_outputDir=%outDir%\client
:: 客户端消息文件目录(客户端只会打包这个目录下面的proto文件)
set client_msg_except_dir_name=internal
@REM 设置一个拷贝目录,将打好的消息自动拷贝到对应的位置
set copyDir=..\..\server\msg

:: 源文件目录
set "src_dir=.\src"
:: 执行文件目录
set "scripts_dir=.\scripts"
set "lib_bin_dir=.\lib\node_modules\.bin"

IF NOT EXIST "%outDir%" (
    echo 输出目录不存在,创建目录...
    mkdir "%outDir%"
)

if not exist "%server_outputDir%" (
    echo 服务器输出目录不存在,创建目录...
    mkdir "%server_outputDir%"
)

if not exist "%client_outputDir%" (
    echo 客户端输出目录不存在,创建目录...
    mkdir "%client_outputDir%"
)

rem setlocal enabledelayedexpansion

for /d %%D in (%src_dir%\*) do (
    if exist "%%D" (
		rem 直接拼接完整路径
		rem set "dirPath=%cd%\%%D"
		rem 检查目录是否为空
		rem echo Checking directory: "!dirPath!"
		dir /b /a-d "%%D\*.proto" >nul 2>&1
		if errorlevel 1 (
			echo INFO: [ %%~nxD ]目录下没有proto文件,跳过
		) else (
			echo INFO: ====== 开始打包--[ %%~nxD ]--中的proto文件
			if not exist "%server_outputDir%\%%~nxD" (
				echo %server_outputDir%\%%~nxD
				mkdir "%server_outputDir%\%%~nxD"
			)
			
			call %scripts_dir%\protoc.exe -I=%src_dir% --plugin=protoc-gen-go="%scripts_dir%\protoc-gen-go.exe" --plugin=protoc-gen-go-grpc="%scripts_dir%\protoc-gen-go-grpc.exe"  --go_out=paths=source_relative:%server_outputDir%  %%D\*.proto --go-grpc_out=paths=source_relative:%server_outputDir%  %%D\*.proto
			if errorlevel 1 (
				echo [ %%~nxD ]生成服务器pb文件失败
				pause
				exit 1
			)
			call %scripts_dir%\protoc-go-inject-tag.exe -input=%server_outputDir%\%%~nxD\*.pb.go
			if errorlevel 1 (
				echo [ %%~nxD ]生成服务器pb标签失败
				pause
				exit 1
			)
			
			rem 根据原始文件生成消息id文件
			for %%M in (%%D\*.proto) do (
				if "%%~nxM" == "msg.proto" (
					call %scripts_dir%\parser.exe %%M %server_outputDir%\%%~nxD\message.go
					if errorlevel 1 (
						echo 生成服务器message文件失败
						pause
						exit 1
					)
					rem 格式化文件
					call %scripts_dir%\gofmt.exe -w %server_outputDir%\%%~nxD\message.go
				)
			)
			

			if not "%%~nxD" == "%client_msg_except_dir_name%" (
 				if not exist "%client_outputDir%\%%~nxD" mkdir "%client_outputDir%\%%~nxD"
@REM 				for %%F in (%%D\*.proto) do @(
@REM 					echo 开始编译 %%~nxF
@REM 					call %lib_bin_dir%\pbjs.cmd "%%F" --ts %client_outputDir%\%%~nxD\%%~nxF.ts
@REM 					if errorlevel 1 (
@REM 						echo ERROR: 编译 [ %%~nxF ] 时出错!
@REM 						pause
@REM 						exit 1
@REM 					) else (
@REM 						echo SUCCESS: 编译 [ %%~nxF ] 完成!
@REM 					)
@REM 				)
				call robocopy %%D "%client_outputDir%\%%~nxD"  /E /NFL /NDL /NJH /NJS
			)
		)
    )
)

if exist "%copyDir%" (
	call robocopy "%server_outputDir%" "%copyDir%" /E /NFL /NDL /NJH /NJS
)

echo.
echo =================proto消息打包完成=====================

pause

