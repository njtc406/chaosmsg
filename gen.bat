@echo off
echo =================��ʼ���proto��Ϣ=====================
echo.

cd .\proto
:: ���������Ŀ¼
set outDir=..\output
:: �������ļ�Ŀ¼
set server_outputDir=%outDir%\server
:: �ͻ����ļ�Ŀ¼
set client_outputDir=%outDir%\client
:: �ͻ�����Ϣ�ļ�Ŀ¼(�ͻ���ֻ�������Ŀ¼�����proto�ļ�)
set client_msg_except_dir_name=internal
@REM ����һ������Ŀ¼,����õ���Ϣ�Զ���������Ӧ��λ��
set copyDir=..\..\server\msg

:: Դ�ļ�Ŀ¼
set "src_dir=.\src"
:: ִ���ļ�Ŀ¼
set "scripts_dir=.\scripts"
set "lib_bin_dir=.\lib\node_modules\.bin"

IF NOT EXIST "%outDir%" (
    echo ���Ŀ¼������,����Ŀ¼...
    mkdir "%outDir%"
)

if not exist "%server_outputDir%" (
    echo ���������Ŀ¼������,����Ŀ¼...
    mkdir "%server_outputDir%"
)

if not exist "%client_outputDir%" (
    echo �ͻ������Ŀ¼������,����Ŀ¼...
    mkdir "%client_outputDir%"
)

rem setlocal enabledelayedexpansion

for /d %%D in (%src_dir%\*) do (
    if exist "%%D" (
		rem ֱ��ƴ������·��
		rem set "dirPath=%cd%\%%D"
		rem ���Ŀ¼�Ƿ�Ϊ��
		rem echo Checking directory: "!dirPath!"
		dir /b /a-d "%%D\*.proto" >nul 2>&1
		if errorlevel 1 (
			echo INFO: [ %%~nxD ]Ŀ¼��û��proto�ļ�,����
		) else (
			echo INFO: ====== ��ʼ���--[ %%~nxD ]--�е�proto�ļ�
			if not exist "%server_outputDir%\%%~nxD" (
				echo %server_outputDir%\%%~nxD
				mkdir "%server_outputDir%\%%~nxD"
			)
			
			call %scripts_dir%\protoc.exe -I=%src_dir% --plugin=protoc-gen-go="%scripts_dir%\protoc-gen-go.exe" --plugin=protoc-gen-go-grpc="%scripts_dir%\protoc-gen-go-grpc.exe"  --go_out=paths=source_relative:%server_outputDir%  %%D\*.proto --go-grpc_out=paths=source_relative:%server_outputDir%  %%D\*.proto
			if errorlevel 1 (
				echo [ %%~nxD ]���ɷ�����pb�ļ�ʧ��
				pause
				exit 1
			)
			call %scripts_dir%\protoc-go-inject-tag.exe -input=%server_outputDir%\%%~nxD\*.pb.go
			if errorlevel 1 (
				echo [ %%~nxD ]���ɷ�����pb��ǩʧ��
				pause
				exit 1
			)
			
			rem ����ԭʼ�ļ�������Ϣid�ļ�
			for %%M in (%%D\*.proto) do (
				if "%%~nxM" == "msg.proto" (
					call %scripts_dir%\parser.exe %%M %server_outputDir%\%%~nxD\message.go
					if errorlevel 1 (
						echo ���ɷ�����message�ļ�ʧ��
						pause
						exit 1
					)
					rem ��ʽ���ļ�
					call %scripts_dir%\gofmt.exe -w %server_outputDir%\%%~nxD\message.go
				)
			)
			

			if not "%%~nxD" == "%client_msg_except_dir_name%" (
 				if not exist "%client_outputDir%\%%~nxD" mkdir "%client_outputDir%\%%~nxD"
@REM 				for %%F in (%%D\*.proto) do @(
@REM 					echo ��ʼ���� %%~nxF
@REM 					call %lib_bin_dir%\pbjs.cmd "%%F" --ts %client_outputDir%\%%~nxD\%%~nxF.ts
@REM 					if errorlevel 1 (
@REM 						echo ERROR: ���� [ %%~nxF ] ʱ����!
@REM 						pause
@REM 						exit 1
@REM 					) else (
@REM 						echo SUCCESS: ���� [ %%~nxF ] ���!
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
echo =================proto��Ϣ������=====================

pause

