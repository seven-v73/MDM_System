# Seven Control sur Windows

Ce guide couvre les postes apprenants Windows dans un parc Seven Control.

## Role de Windows dans Seven Control

Sur Windows, la machine apprenant peut utiliser:

- Veyon Service pour le controle distant, le verrouillage et l'observation;
- Seven Control Location Agent pour la localisation MDM autorisee;
- un inventaire Seven Control avec nom machine, IP ou DNS, MAC et salle.

Les commandes d'orchestration `seven-control-lock`, `seven-control-import-inventory` et `seven-control-health-check` restent prevues pour le poste admin Linux/sevenOS pour l'instant. Elles peuvent agir sur des machines Windows si Veyon Service y est installe et joignable.

## Prerequis poste apprenant

1. Installer Veyon Service pour Windows.
2. Importer ou configurer les cles d'authentification Veyon.
3. Autoriser le port Veyon dans le pare-feu Windows.
4. Donner a la machine un nom stable ou une reservation DHCP.
5. Ajouter la machine dans l'inventaire Seven Control.

Exemple d'inventaire:

```csv
location;name;host;mac
Paris-Salle-1;WIN-S1-PC01;win-s1-pc01.ad.example.local;AA:BB:CC:DD:EE:10
```

## Localisation MDM autorisee

Prerequis:

- Python 3 installe.
- PowerShell lance en administrateur.
- URL du serveur Seven Control Location.
- Jeton d'enrolement.

Installation:

```powershell
powershell -ExecutionPolicy Bypass -File .\seven-control\location\windows\install-location-agent.ps1 `
  -ServerUrl "https://seven-control.example.org" `
  -Token "TOKEN_ENROLEMENT" `
  -DeviceName "WIN-S1-PC01"
```

Le script cree:

- `C:\Program Files\SevenControl\seven_control_location_agent.py`;
- `C:\ProgramData\SevenControl\location-agent.env`;
- `C:\ProgramData\SevenControl\location-notice.accepted`;
- une tache planifiee `Seven Control Location Agent`.

Test:

```powershell
python "C:\Program Files\SevenControl\seven_control_location_agent.py"
```

## Sources disponibles sur Windows

- IP locale via Python et `ipconfig`.
- Wi-Fi via `netsh wlan show networks mode=bssid`.
- IP publique optionnelle si `SEVEN_CONTROL_PUBLIC_IP_URL` est configure.
- GPS uniquement si un recepteur compatible expose une source lisible par un outil ajoute au poste. Le support GPS natif Windows n'est pas active dans cet agent initial.

## Verification depuis le poste admin

Depuis sevenOS/Linux admin:

```bash
seven-control-health-check --location Paris-Salle-1
seven-control-locate WIN-S1-PC01
seven-control-lock lock --location Paris-Salle-1
```
