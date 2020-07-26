# escape=`

ARG WINDOWSBASEIMAGE=windows/nanoserver
ARG WINDOWSIMAGETAG=2004-amd64
ARG NODEVERSION=12.18.3
ARG NPMVERSION
ARG YARNVERSION

FROM mcr.microsoft.com/windows/servercore:${WINDOWSIMAGETAG} AS download
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
    Remove-Item -Force -Recurse -Verbose "C:\Tools\Temp"; `
    Rename-Item -Verbose $NodeExpandDest 'C:\Tools\NodeJs'

FROM mcr.microsoft.com/${WINDOWSBASEIMAGE}:${WINDOWSIMAGETAG}
ARG NPMVERSION
ARG YARNVERSION
COPY --from=download C:\Tools\NodeJs C:\Tools\NodeJs
ADD *.cmd C:\Users\Public\Downloads\HelperScripts\
RUN (`
        CALL C:\Users\Public\Downloads\HelperScripts\node-path-append.cmd "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" 2> NUL || `
        CALL C:\Users\Public\Downloads\HelperScripts\node-path-append.cmd "HKCU\Environment"`
    ) &&`
    ERASE C:\Users\Public\Downloads\HelperScripts\node-path-append.cmd
RUN CALL C:\Users\Public\Downloads\HelperScripts\node-extra-install.cmd && `
    CALL C:\Users\Public\Downloads\HelperScripts\node-extra-setenv.cmd && `
    ERASE C:\Users\Public\Downloads\HelperScripts\*.cmd && `
    RD /S /Q C:\Users\Public\Downloads\HelperScripts
