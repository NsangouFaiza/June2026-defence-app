$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
if (Test-Path "$scriptDir\venv\Scripts\Activate.ps1") {
    & "$scriptDir\venv\Scripts\Activate.ps1"
} elseif (Test-Path "$scriptDir\..\lifelink-backend\venv\Scripts\Activate.ps1") {
    & "$scriptDir\..\lifelink-backend\venv\Scripts\Activate.ps1"
} elseif (Test-Path "$scriptDir\..\.venv\Scripts\Activate.ps1") {
    & "$scriptDir\..\.venv\Scripts\Activate.ps1"
}
python manage.py runserver
