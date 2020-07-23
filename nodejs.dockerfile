# escape=`

ARG WINDOWSBASEIMAGE=windows/nanoserver
ARG WINDOWSIMAGETAG=2004-amd64
ARG NODEVERSION=12.18.3
ARG NPMVERSION
ARG YARNVERSION

FROM mcr.microsoft.com/windows/servercore:${WINDOWSIMAGETAG} AS download
ARG NODEVERSION
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN `
    [uri]$NodeZipUri = ('https://nodejs.org/dist/v{0}/node-v{0}-win-x64.zip' -f $ENV:NODEVERSION); `
    $NodeZipFileName = $NodeZipUri.Segments | Select-Object -Last 1; `
    $NodeZipFilePath = Join-Path $ENV:TEMP $NodeZipFileName; `
    Write-Host ('Downloading Node.js windows zip distribution v{0} from {1}' -f $ENV:NODEVERSION, $NodeZipUri); `
    Invoke-WebRequest $NodeZipUri -OutFile $NodeZipFilePath; `
    $NodeZipFileItem = Get-Item $NodeZipFilePath; `
    Expand-Archive $NodeZipFilePath -DestinationPath 'C:\Tools'; `
    $NodeExpandDest = Join-Path -Resolve 'C:\Tools' $NodeZipFileItem.BaseName; `
    Remove-Item -Force -Verbose $NodeZipFilePath; `
    Rename-Item -Verbose $NodeExpandDest 'C:\Tools\NodeJs'

FROM mcr.microsoft.com/${WINDOWSBASEIMAGE}:${WINDOWSIMAGETAG}
ARG NPMVERSION
ARG YARNVERSION
ARG NPM_CONFIG_PREFIX=C:\Tools\Npm-Global
COPY --from=download C:\Tools\NodeJs C:\Tools\NodeJs
USER Administrator
RUN ECHO.@ECHO OFF> C:\Tools\path-append-helper.cmd && `
    ECHO.ECHO.Appending Path variable in HKLM Registry with>> C:\Tools\path-append-helper.cmd && `
    ECHO.ECHO.;%%%1%%;%%%1%%\bin;%~2;%~2\bin;C:\Tools\NodeJs>> C:\Tools\path-append-helper.cmd && `
    ECHO.FOR /F "tokens=1,2,* delims= " %%A IN ('REG QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path') DO (>> C:\Tools\path-append-helper.cmd &&`
    ECHO.    IF /I "%%~A"=="Path" (>> C:\Tools\path-append-helper.cmd &&`
    ECHO.        REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%%~A" /t "%%~B" /d "%%~C;%%%1%%;%%%1%%\bin;%~2;%~2\bin;C:\Tools\NodeJs" /f>> C:\Tools\path-append-helper.cmd &&`
    ECHO.    )>> C:\Tools\path-append-helper.cmd &&`
    ECHO.)>> C:\Tools\path-append-helper.cmd &&`
    CALL C:\Tools\path-append-helper.cmd NPM_CONFIG_PREFIX "%NPM_CONFIG_PREFIX%" && `
    SETX /M NPM_CONFIG_PREFIX "%NPM_CONFIG_PREFIX%" && `
    ERASE C:\Tools\path-append-helper.cmd
RUN ECHO.@ECHO OFF> C:\Tools\node-extra-install.cmd && `
    ECHO.SET NPMINSTALLCOMMAND=npm install --cache "%TEMP%\npm-cache" --global>>  C:\Tools\node-extra-install.cmd && `
    ECHO.IF NOT "%NPMVERSION%"=="" (cmd /C %NPMINSTALLCOMMAND% "npm@%NPMVERSION%") >> C:\Tools\node-extra-install.cmd && `
    ECHO.IF /I "%YARNVERSION%"=="" (cmd /C %NPMINSTALLCOMMAND% yarn) ELSE (cmd /C %NPMINSTALLCOMMAND% "yarn@%YARNVERSION%")>>  C:\Tools\node-extra-install.cmd && `
    ECHO.RD /S /Q "%TEMP%\npm-cache">>  C:\Tools\node-extra-install.cmd && `
    ECHO.@ECHO OFF >  C:\Tools\node-setenv.cmd && `
    ECHO.FOR /F "delims=v" %%V IN ('node -v')    DO @SETX /M NODEVERSION "%%~V">> C:\Tools\node-setenv.cmd && `
    ECHO.FOR /F "delims=v" %%V IN ('npm -v')     DO @SETX /M NPMVERSION  "%%~V">> C:\Tools\node-setenv.cmd && `
    ECHO.FOR /F            %%V IN ('yarn -v')    DO @SETX /M YARNVERSION "%%~V">> C:\Tools\node-setenv.cmd && `
    CALL C:\Tools\node-extra-install.cmd &&`
    CALL C:\Tools\node-setenv.cmd &&`
    ERASE C:\Tools\node-extra-install.cmd C:\Tools\node-setenv.cmd
USER ContainerUser
