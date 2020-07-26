@ECHO OFF
(
    CALL "%~dp0.\node-path-append.cmd" "HKLM\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" 2> NUL
) || (
    CALL "%~dp0.\node-path-append.cmd" "HKCU\Environment"
)
