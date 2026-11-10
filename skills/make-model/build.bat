@echo off
rem Blender -> Roblox model pipeline. Method by fwjelaa (FWJ STUDIOS). See CREDITS.md.
rem Usage:  .\build BearBuddy          build + render + out\compare_BearBuddy.png
rem         .\build BearBuddy export   also bake the Roblox mesh: out\BearBuddy.fbx + textures
rem Blender is found automatically (see kit\run.py).
setlocal
set "PY=python"
where python >nul 2>nul || set "PY=py -3"
if "%~1"=="" (
  echo Usage: .\build ModelId [export]
  exit /b 1
)
if /i "%~2"=="export" (
  %PY% "%~dp0kit\run.py" export %~1
) else (
  %PY% "%~dp0kit\run.py" build %~1
)
