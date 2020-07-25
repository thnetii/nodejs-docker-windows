@ECHO OFF
REM Temporarily disable NPM_CONFIG_PREFIX
SETLOCAL
SET NPM_CONFIG_PREFIX=
SET NPMINSTALLCOMMAND=npm install --cache "%TEMP%\npm-cache" --global
IF NOT "%NPMVERSION%"=="" (
    cmd /C %NPMINSTALLCOMMAND% --force "npm@%NPMVERSION%"
)
IF "%YARNVERSION%"=="" (
    cmd /C %NPMINSTALLCOMMAND% yarn
) ELSE (
    cmd /C %NPMINSTALLCOMMAND% "yarn@%YARNVERSION%"
)
RD /S /Q "%TEMP%\npm-cache"
ENDLOCAL
