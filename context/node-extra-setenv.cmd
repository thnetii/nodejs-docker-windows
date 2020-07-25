@ECHO OFF
FOR /F "delims=v" %%V IN ('node -v')    DO (SETX /M NODEVERSION "%%~V" 2> NUL || SETX NODEVERSION "%%~V")
FOR /F "delims=v" %%V IN ('npm -v')     DO (SETX /M NPMVERSION  "%%~V" 2> NUL || SETX NPMVERSION  "%%~V")
FOR /F            %%V IN ('yarn -v')    DO (SETX /M YARNVERSION "%%~V" 2> NUL || SETX YARNVERSION "%%~V")
