@ECHO OFF
SETLOCAL
REM %1: Registry Key to change

ECHO.Modifying Registry key %~1
REG QUERY "%~1" /v Path 1> NUL 2> NUL || (
    ECHO.Creating missing registry key %~1 and setting Path value to empty
    REG ADD "%~1" /v Path /t REG_EXPAND_SZ /d "" 1> NUL
) || GOTO ERRORMESSAGE

SET NPM_PATH_APPEND=;%%NPM_CONFIG_PREFIX%%;%%NPM_CONFIG_PREFIX%%\bin;C:\Tools\NodeJs
FOR /F "tokens=1,2,* delims= " %%A IN ('REG QUERY "%~1" /v Path') DO (
    IF /I "%%~A"=="Path" (
        ECHO.Appending "%NPM_PATH_APPEND%" to Path value "%%~C"
        REG ADD "%~1" /v "%%~A" /t REG_EXPAND_SZ /d "%%~C%NPM_PATH_APPEND%" /f || GOTO ERRORMESSAGE
    )
)

ECHO.Setting NPM_CONFIG_PREFIX value to %%APPDATA%%\npm
REG ADD "%~1" /v NPM_CONFIG_PREFIX /t REG_EXPAND_SZ /d "%%APPDATA%%\npm" || GOTO ERRORMESSAGE
ENDLOCAL
GOTO :EOF

:ERRORMESSAGE
ECHO.Unable to modify registry key
