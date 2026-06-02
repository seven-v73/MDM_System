$ErrorActionPreference = "Stop"
$agent = "C:\Program Files\SevenControl\seven_control_location_agent.py"
if (-not (Test-Path $agent)) {
	throw "Agent introuvable: $agent"
}
python $agent
