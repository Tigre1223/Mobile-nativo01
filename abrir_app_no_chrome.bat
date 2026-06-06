@echo off
setlocal
cd /d "%~dp0"

set "APP_URL=http://127.0.0.1:52932"
set "APP_URL_NOCACHE=http://127.0.0.1:52932/?v=%RANDOM%%RANDOM%"
set "FLUTTER=..\work\flutter_sdk\flutter\bin\flutter.bat"
set "PYTHON=C:\Users\alven\.cache\codex-runtimes\codex-primary-runtime\dependencies\python\python.exe"
set "WORK_ROOT=%~dp0..\work"
set "GIT_CONFIG_GLOBAL=%WORK_ROOT%\gitconfig"
set "APPDATA=%WORK_ROOT%\appdata"
set "LOCALAPPDATA=%WORK_ROOT%\localappdata"
set "PUB_CACHE=%WORK_ROOT%\pub-cache"

if not exist "%PYTHON%" (
  echo Python local nao encontrado em "%PYTHON%".
  pause
  exit /b 1
)

if not exist "build\web\index.html" (
  if not exist "%FLUTTER%" (
    echo Flutter SDK nao encontrado em "%FLUTTER%".
    pause
    exit /b 1
  )
  echo Gerando build web...
  call "%FLUTTER%" build web --no-wasm-dry-run
)

netstat -ano | find ":52932" | find "LISTENING" >nul
if errorlevel 1 (
  echo Iniciando servidor local do build web...
  start "Controle Financeiro" /min "%PYTHON%" -m http.server 52932 --bind 127.0.0.1 --directory "%~dp0build\web"
)

echo Aguardando o app ficar pronto...
for /l %%i in (1,1,60) do (
  powershell -NoProfile -Command "try { $r = Invoke-WebRequest -Uri '%APP_URL%/flutter_bootstrap.js' -UseBasicParsing -TimeoutSec 2; if ($r.StatusCode -eq 200) { exit 0 } else { exit 1 } } catch { exit 1 }" >nul 2>nul
  if not errorlevel 1 goto abrir_chrome
  timeout /t 2 /nobreak >nul
)

:abrir_chrome

where chrome >nul 2>nul
if %errorlevel%==0 (
  start "" chrome "%APP_URL_NOCACHE%"
  exit /b 0
)

if exist "%ProgramFiles%\Google\Chrome\Application\chrome.exe" (
  start "" "%ProgramFiles%\Google\Chrome\Application\chrome.exe" "%APP_URL_NOCACHE%"
  exit /b 0
)

if exist "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" (
  start "" "%ProgramFiles(x86)%\Google\Chrome\Application\chrome.exe" "%APP_URL_NOCACHE%"
  exit /b 0
)

echo Google Chrome nao foi encontrado. Abrindo no navegador padrao...
start "" "%APP_URL_NOCACHE%"
