# Seven Control Location

Seven Control Location ajoute une localisation MDM autorisee pour les machines du parc.

Ce module ne doit etre active que sur des machines appartenant a l'organisation ou explicitement enrolees. Il n'est pas concu pour une surveillance cachee: l'agent refuse de transmettre si le fichier d'information locale n'existe pas.

## Sources de localisation

- GPS via `gpsd`/`gpspipe` sur Linux, si le materiel le permet.
- Wi-Fi via `nmcli` sur Linux, `netsh wlan` sur Windows, `airport` sur macOS.
- IP locale et IP publique optionnelle.
- Inventaire Seven Control/Veyon pour la salle, le campus ou la promo.

Sur un PC portable classique, le GPS est souvent absent. Dans ce cas, la localisation exacte n'est pas garantie.

## Serveur Linux

Copier l'exemple de configuration:

```bash
sudo install -d /etc/seven-control
sudo install -m 0600 seven-control/location/server.env.example /etc/seven-control/location-server.env
sudo nano /etc/seven-control/location-server.env
```

Demarrer le serveur:

```bash
sudo systemctl enable --now seven-control-location-server.service
```

Lister les machines depuis le serveur:

```bash
curl -H "Authorization: Bearer ADMIN_TOKEN" http://127.0.0.1:8765/api/devices
```

Ou avec la CLI admin:

```bash
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin list
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin list --stale-minutes 60
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin status
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin get sc-xxxxxxxxxxxxxxxx
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin export-csv positions.csv
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin export-geojson positions.geojson
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin audit --limit 50
```

Purger l'historique plus ancien que 30 jours:

```bash
SEVEN_CONTROL_LOCATION_ADMIN_TOKEN=ADMIN_TOKEN seven-control-location-admin purge --older-than-days 30
```

La purge concerne l'historique `events.jsonl`. Le dernier etat par machine reste disponible dans `latest/`.

Generer des tokens forts avant de remplir les fichiers `.env`:

```bash
seven-control-location-admin generate-token
seven-control-location-admin generate-token --bytes 48
```

## Agent apprenant

### Linux avec systemd

Installer la configuration:

```bash
sudo install -d /etc/seven-control
sudo install -m 0600 seven-control/location/agent.env.example /etc/seven-control/location-agent.env
sudo nano /etc/seven-control/location-agent.env
```

Activer explicitement l'information locale:

```bash
echo "Seven Control Location active sur cette machine administree." | sudo tee /etc/seven-control/location-notice.accepted
```

Demarrer l'agent periodique:

```bash
sudo systemctl enable --now seven-control-location-agent.timer
```

Test manuel:

```bash
sudo systemctl start seven-control-location-agent.service
```

### Windows

Prerequis:

- Windows 10/11 ou Windows Server recent.
- Python 3 installe.
- PowerShell lance en administrateur.

Installer l'agent:

```powershell
powershell -ExecutionPolicy Bypass -File .\seven-control\location\windows\install-location-agent.ps1 `
  -ServerUrl "https://seven-control.example.org" `
  -Token "TOKEN_ENROLEMENT" `
  -DeviceName "PC-APPRENANT-01"
```

Le script installe:

- l'agent dans `C:\Program Files\SevenControl`;
- la configuration dans `C:\ProgramData\SevenControl\location-agent.env`;
- le fichier d'information dans `C:\ProgramData\SevenControl\location-notice.accepted`;
- une tache planifiee `Seven Control Location Agent`.

Test manuel:

```powershell
powershell -ExecutionPolicy Bypass -File "C:\Program Files\SevenControl\run-location-agent.ps1"
```

Si le test manuel ne trouve pas `run-location-agent.ps1`, lancez directement:

```powershell
python "C:\Program Files\SevenControl\seven_control_location_agent.py"
```

### macOS

Prerequis:

- Python 3 installe.
- Droits administrateur.

Installer l'agent:

```bash
sudo ./seven-control/location/macos/install-location-agent.sh
sudo nano "/Library/Application Support/SevenControl/location-agent.env"
```

Le script installe un LaunchDaemon `com.sevencontrol.location-agent` qui execute l'agent toutes les 15 minutes.

Test manuel:

```bash
sudo /usr/local/bin/python3 /usr/local/seven-control/location/seven_control_location_agent.py
```

### Linux sans Arch/sevenOS

L'agent est un script Python 3 portable. Sur Debian/Ubuntu, installez au minimum:

```bash
sudo apt install python3 network-manager gpsd gpsd-clients
```

Puis utilisez le meme service systemd fourni dans ce dossier, ou lancez l'agent via cron/timer selon votre distribution.

## Cadre minimum

Avant activation massive:

1. Definir la finalite: securite du parc, perte/vol, support ou inventaire.
2. Informer les apprenants et personnels concernes.
3. Limiter l'acces aux admins autorises.
4. Journaliser chaque consultation admin.
5. Definir une duree de conservation courte.
6. Desactiver la localisation sur les machines hors perimetre.

## API admin

Endpoints disponibles:

- `GET /api/devices`: dernier etat de toutes les machines.
- `GET /api/status`: etat du serveur, volume d'evenements et retention.
- `GET /api/device?id=DEVICE_ID`: dernier etat d'une machine.
- `GET /api/audit?limit=50`: derniers evenements d'audit.
- `DELETE /api/events?older_than_days=30`: purge l'historique ancien.

Tous les endpoints admin exigent:

```http
Authorization: Bearer ADMIN_TOKEN
```
