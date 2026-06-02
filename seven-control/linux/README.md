# Seven Control sur Linux generique

Ce guide cible Debian, Ubuntu, Fedora et autres distributions non Arch.

## Poste admin

Installez Veyon avec les paquets de votre distribution ou depuis les sources du projet. Les scripts Seven Control sont des scripts shell et Python, donc ils peuvent etre installes sur la plupart des distributions avec:

```bash
./seven-control/install-seven-control.sh
```

Dependances utiles:

```bash
sudo apt install python3 network-manager gpsd gpsd-clients
```

Adaptez la commande selon votre distribution.

## Poste apprenant

1. Installer Veyon Service.
2. Activer le service:

```bash
sudo systemctl enable --now veyon.service
```

3. Configurer les cles Veyon.
4. Ouvrir le port Veyon dans le pare-feu local.
5. Ajouter la machine dans l'inventaire Seven Control.

## Localisation MDM autorisee

Installer la configuration agent:

```bash
sudo install -d /etc/seven-control
sudo install -m 0600 seven-control/location/agent.env.example /etc/seven-control/location-agent.env
sudo nano /etc/seven-control/location-agent.env
```

Activer explicitement l'information locale:

```bash
echo "Seven Control Location active sur cette machine administree." | sudo tee /etc/seven-control/location-notice.accepted
```

Installer les services systemd fournis ou copier les scripts dans un chemin equivalent:

```bash
sudo ./seven-control/install-seven-control.sh
sudo systemctl daemon-reload
sudo systemctl enable --now seven-control-location-agent.timer
```

## Sources disponibles sur Linux

- GPS via `gpsd` et `gpspipe`.
- Wi-Fi via `nmcli`.
- IP locale via Python et `ip`.
- IP publique optionnelle si `SEVEN_CONTROL_PUBLIC_IP_URL` est configure.
