# Seven Control sur macOS

Ce guide couvre le module Seven Control Location sur macOS.

Les scripts d'orchestration Veyon/Seven Control sont principalement prevus pour un poste admin Linux/sevenOS. Sur macOS, le support ajoute ici concerne surtout l'agent de localisation MDM autorisee.

## Prerequis

- Python 3 installe.
- Droits administrateur.
- URL du serveur Seven Control Location.
- Jeton d'enrolement.

## Installation de l'agent

```bash
sudo ./seven-control/location/macos/install-location-agent.sh
sudo nano "/Library/Application Support/SevenControl/location-agent.env"
```

Le script installe:

- `/usr/local/seven-control/location/seven_control_location_agent.py`;
- `/Library/Application Support/SevenControl/location-agent.env`;
- `/Library/Application Support/SevenControl/location-notice.accepted`;
- `/Library/LaunchDaemons/com.sevencontrol.location-agent.plist`.

Test:

```bash
sudo /usr/local/bin/python3 /usr/local/seven-control/location/seven_control_location_agent.py
```

## Sources disponibles sur macOS

- IP locale via Python.
- Wi-Fi via l'outil systeme `airport` quand disponible.
- IP publique optionnelle si `SEVEN_CONTROL_PUBLIC_IP_URL` est configure.
- GPS seulement si un materiel ou logiciel tiers fournit une source exploitable. Le support GPS natif macOS n'est pas active dans cet agent initial.
