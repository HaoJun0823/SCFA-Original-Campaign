@echo off
setlocal enableDelayedExpansion

if "%1" == "" (
	for %%W in (*.xwb) do ( 
		call :convert %%W
	)
) else if exist %~n1.xwb (
	if "%2" == "" (
		call :convert %%~n1
	) else if "%2" == "/d" (
		mkdir output
		unxwb -d output -D %~n1.xwb
		call :convertWav %~n1
	) else (
		mkdir output
		unxwb -d output -b %~n1.xsb %2 %~n1.xwb
		
		call :convertWav %~n1
	)
) else echo "Error: File does not exist: %~n1.xwb"
pause
goto :eof

:convert
rmdir /s /q output
mkdir output

for /f "tokens=*" %%A in ('hexdump /S43 /N1 %~n1.xsb') do set offset1=%%A
for /f "tokens=*" %%A in ('hexdump /S42 /N1 %~n1.xsb') do set offset2=%%A
set offset=0x!offset1:~0,2!!offset2:~0,2!

unxwb -d output -b %~n1.xsb !offset! %~n1.xwb

:convertWav
rem Delete this line if you don't want to clear the output dir
rmdir /s /q %~n1

mkdir %~n1
for %%F in (.\output\*.wav) do ffmpeg -i %%F -c pcm_s16le -f wav .\%~n1\%%~nxF
rmdir /s /q output
goto :eof