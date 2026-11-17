@echo off
rem ============================================================
rem  NexStay - Pantalla de la habitacion (mini PC del cuarto)
rem  La primera vez pide la IP de la laptop de recepcion y la
rem  recuerda (archivo servidor.txt). La habitacion se elige en la
rem  pantalla "Configurar esta pantalla" la primera vez.
rem ============================================================
cd /d "%~dp0"
set SERVIDOR=
if exist "servidor.txt" set /p SERVIDOR=<"servidor.txt"
if not defined SERVIDOR (
    echo.
    echo Escribe la IP de la laptop de recepcion.
    echo La ves en la app de recepcion, abajo a la izquierda, en "IP del hotel".
    echo Si esta es la laptop de recepcion, escribe: localhost
    echo.
    set /p SERVIDOR=IP: 
)
if not defined SERVIDOR exit /b 1
>"servidor.txt" echo %SERVIDOR%
set BASE=\\%SERVIDOR%\NexStayDatos\nexstay_hotel.db

if not exist "\\%SERVIDOR%\NexStayDatos\" (
    echo.
    echo No se encuentra la carpeta compartida \\%SERVIDOR%\NexStayDatos
    echo - Revisa que la laptop de recepcion este encendida y en el mismo WiFi.
    echo - Si pide usuario y contrasena, usa la cuenta nexstay de la laptop de recepcion.
    echo - Si la IP cambio, borra el archivo servidor.txt y vuelve a abrir este archivo.
    echo.
    pause
    exit /b 1
)
start "" "%~dp0appNexStay.exe" --kiosko "--db=%BASE%"
