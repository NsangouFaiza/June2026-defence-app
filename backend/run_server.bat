@echo off
cd /d "%~dp0"
if exist "%~dp0venv\Scripts\activate.bat" (
    call "%~dp0venv\Scripts\activate.bat"
) else if exist "%~dp0..\lifelink-backend\venv\Scripts\activate.bat" (
    call "%~dp0..\lifelink-backend\venv\Scripts\activate.bat"
) else if exist "%~dp0..\.venv\Scripts\activate.bat" (
    call "%~dp0..\.venv\Scripts\activate.bat"
)
python manage.py runserver
