# escape=`

ARG WINDOWSDOWNLOADTAG=2004-amd64
ARG BASEIMAGE=mcr.microsoft.com/windows/nanoserver:${WINDOWSDOWNLOADTAG}
ARG NODEVERSION=12.18.3
ARG NPMVERSION
ARG YARNVERSION

FROM mcr.microsoft.com/windows/servercore:${WINDOWSDOWNLOADTAG} AS download
ARG NODEVERSION
ADD https://nodejs.org/dist/v${NODEVERSION}/node-v${NODEVERSION}-win-x64.zip C:\Tools\Temp\
SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]
RUN `
    $NodeZipFileName = ('node-v{0}-win-x64.zip' -f $ENV:NODEVERSION); `
    $NodeZipFilePath = Join-Path -Resolve "C:\Tools\Temp" $NodeZipFileName; `
    $NodeZipFileItem = Get-Item $NodeZipFilePath; `
    Write-Host "Extracting $($NodeZipFileItem.FullName) to C:\Tools"; `
    Expand-Archive $NodeZipFilePath -DestinationPath 'C:\Tools'; `
    $NodeExpandDest = Join-Path -Resolve 'C:\Tools' $NodeZipFileItem.BaseName; `
    Remove-Item -Force -Recurse -Verbose "C:\Tools\Temp"

FROM ${BASEIMAGE}
ARG NODEVERSION
ARG NPMVERSION
ARG YARNVERSION
COPY --from=download C:\Tools\node-v${NODEVERSION}-win-x64 C:\Tools\node-v${NODEVERSION}-win-x64
ADD *.cmd C:\Users\Public\Downloads\HelperScripts\
RUN C:\Users\Public\Downloads\HelperScripts\node-pathsetup.cmd
RUN C:\Users\Public\Downloads\HelperScripts\node-postsetup.cmd
