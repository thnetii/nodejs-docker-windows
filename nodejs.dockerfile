# escape=`

ARG WINDOWSBASEIMAGE=windows/nanoserver
ARG WINDOWSIMAGETAG=2004-amd64
ARG NODEVERSION=12.18.3
ARG NPMVERSION

FROM mcr.microsoft.com/windows/servercore:${WINDOWSIMAGETAG} AS download
ARG NODEVERSION
ENV NODEVERSION=${NODEVERSION}
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
ARG NODEVERSION
ARG NPMVERSION
ARG YARNVERSION
ENV NODEVERSION=${NODEVERSION}
ENV NPMVERSION=${NPMVERSION}
ENV YARNVERSION=${YARNVERSION}
COPY --from=download C:\Tools\NodeJs C:\Tools\NodeJs
USER Administrator
RUN FOR /F "tokens=1,2,* delims= " %A IN ('REG QUERY "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v Path') DO `
        @IF /I "%~A"=="Path" `
            REG ADD "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" /v "%~A" /t "%~B" /d "%~C;C:\Tools\NodeJs" /f
RUN ECHO.(IF /I "${NPMVERSION:-}"==""   (npm install --global npm)  ELSE (npm install --global "npm@${NPMVERSION}")) && `
    ECHO.(IF /I "${YARNVERSION:-}"==""  (npm install --global yarn) ELSE (npm install --global "yarn@${YARNVERSION}")) && `
    ECHO.(FOR /F "delims=v" %V IN ('node -v')    DO @SETX /M NODEVERSION "%~V") && `
    ECHO.(FOR /F "delims=v" %V IN ('npm -v')     DO @SETX /M NPMVERSION  "%~V") && `
    ECHO.(FOR /F            %v IN ('yarn -v')    DO @SETX /M YARNVERSION "%~V")
USER ContainerUser
RUN SET
