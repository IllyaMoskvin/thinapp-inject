@echo off

setlocal

set PROJECT_DIR=%PROJECT_PATH%
if exist %PROJECT_PATH% goto haspath
set PROJECT_DIR=%~dp0
:haspath

Rem default is %PROJECT_DIR%\bin
set TARGET_DIR=%PROJECT_DIR%\bin


rem If Package.ini has an OutDir option, set TARGET_DIR to OutDir
For /F "tokens=* delims=" %%A in ('type "%PROJECT_DIR%\Package.ini" ^| findstr "OutDir="') Do set IniOutDir=%%A
if "%IniOutDir:~0,7%"=="OutDir=" set TARGET_DIR=%IniOutDir:~7%
if NOT "%TARGET_DIR:~1,2%"==":\" if NOT "%TARGET_DIR:~0,2%"=="\\" set TARGET_DIR=%PROJECT_DIR%\%TARGET_DIR%

if exist "%THINSTALL_BIN%\vregtool.exe" goto found
set THINSTALL_BIN=%PROJECT_DIR%\..\..
if exist "%THINSTALL_BIN%\vregtool.exe" goto found
rem Removed reference to local install
set "THINSTALL_BIN=%ProgramFiles(x86)%\VMware\VMware ThinApp"
if exist "%THINSTALL_BIN%\vregtool.exe" goto found
set "THINSTALL_BIN=%ProgramFiles%\VMware\VMware ThinApp"
if exist "%THINSTALL_BIN%\vregtool.exe" goto found
echo Could not find vregtool.exe, please set the environment variable THINSTALL_BIN or install to C:\Program Files (x86)\VMware\VMware ThinApp
goto failed

:found
if not exist "%THINSTALL_BIN%\vftool.exe" goto failed
if not exist "%THINSTALL_BIN%\tlink.exe" goto failed

if not exist "%TARGET_DIR%" mkdir "%TARGET_DIR%"
if exist "%TARGET_DIR%\*.exe" del /f /q "%TARGET_DIR%\*.exe"
if exist "%TARGET_DIR%\*.exe" goto failed
if exist "%TARGET_DIR%\*.dat" del /f /q "%TARGET_DIR%\*.dat"
if exist "%TARGET_DIR%\*.dat" goto failed
if exist "%TARGET_DIR%\*.msi" del /f /q "%TARGET_DIR%\*.msi"
if exist "%TARGET_DIR%\*.msi" goto failed
if exist "%TARGET_DIR%\*.alt" del /f /q "%TARGET_DIR%\*.alt"
if exist "%TARGET_DIR%\*.alt" goto failed

"%THINSTALL_BIN%\vregtool" "%TARGET_DIR%\Package.ro.tvr" ImportDir "%PROJECT_DIR%"
IF ERRORLEVEL 1 GOTO failed

"%THINSTALL_BIN%\vftool" "%TARGET_DIR%\Package.ro.tvr" ImportDir "%PROJECT_DIR%"
IF ERRORLEVEL 1 GOTO failed

"%THINSTALL_BIN%\tlink" "%PROJECT_DIR%\Package.ini" -OutDir "%TARGET_DIR%"
IF ERRORLEVEL 1 GOTO failed

goto done

:failed
echo *** Build failed ***
goto final

:done
del "%TARGET_DIR%\*.tvr"
del "%TARGET_DIR%\*.tvr.thfd"
echo ---------------------------------------------
echo Build complete

:final
exit /b %ERRORLEVEL%

endlocal
