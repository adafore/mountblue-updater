@echo off
if not exist "%~dp0PovinePsani.ahk" (
    echo Soubor Nastaveni.cmd musi byt vedle PovinePsani.ahk.
    pause
    exit /b 1
)
start "" "%~dp0PovinePsani.ahk" --setup
