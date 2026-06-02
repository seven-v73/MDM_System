param(
	[string]$InstallDir = "C:\Program Files\SevenControl",
	[string]$ConfigDir = "C:\ProgramData\SevenControl",
	[string]$ServerUrl = "",
	[string]$Token = "",
	[string]$DeviceName = "",
	[int]$IntervalMinutes = 15
)

$ErrorActionPreference = "Stop"

if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
	throw "Lancez ce script dans PowerShell en administrateur."
}

$python = Get-Command python -ErrorAction SilentlyContinue
if (-not $python) {
	$python = Get-Command py -ErrorAction SilentlyContinue
}
if (-not $python) {
	throw "Python est introuvable. Installez Python 3 avant d'installer l'agent."
}

New-Item -ItemType Directory -Force -Path $InstallDir | Out-Null
New-Item -ItemType Directory -Force -Path $ConfigDir | Out-Null

$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$agentSource = Join-Path (Split-Path -Parent $scriptRoot) "seven_control_location_agent.py"
$agentTarget = Join-Path $InstallDir "seven_control_location_agent.py"
Copy-Item -Force $agentSource $agentTarget
Copy-Item -Force (Join-Path $scriptRoot "run-location-agent.ps1") (Join-Path $InstallDir "run-location-agent.ps1")

$envPath = Join-Path $ConfigDir "location-agent.env"
if (-not (Test-Path $envPath)) {
@"
SEVEN_CONTROL_LOCATION_SERVER_URL=$ServerUrl
SEVEN_CONTROL_LOCATION_TOKEN=$Token
SEVEN_CONTROL_DEVICE_NAME=$DeviceName
SEVEN_CONTROL_LOCATION_NOTICE_FILE=C:\ProgramData\SevenControl\location-notice.accepted
SEVEN_CONTROL_PUBLIC_IP_URL=
"@ | Set-Content -Encoding UTF8 $envPath
}

$noticePath = Join-Path $ConfigDir "location-notice.accepted"
if (-not (Test-Path $noticePath)) {
	"Seven Control Location active sur cette machine administree." | Set-Content -Encoding UTF8 $noticePath
}

$pythonExe = $python.Source
if ($python.Name -eq "py.exe") {
	$action = New-ScheduledTaskAction -Execute $pythonExe -Argument "-3 `"$agentTarget`""
} else {
	$action = New-ScheduledTaskAction -Execute $pythonExe -Argument "`"$agentTarget`""
}
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes)
$principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -RunLevel Highest
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable

Register-ScheduledTask -TaskName "Seven Control Location Agent" -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null

Write-Host "Seven Control Location Agent installe."
Write-Host "Configuration: $envPath"
Write-Host "Tache planifiee: Seven Control Location Agent"
