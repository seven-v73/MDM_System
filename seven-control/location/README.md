# Seven Control Location

Seven Control Location ajoute une localisation MDM autorisee pour les machines du parc.

Ce module ne doit etre active que sur des machines appartenant a l'organisation ou explicitement enrolees. Il n'est pas concu pour une surveillance cachee: l'agent refuse de transmettre si le fichier d'information locale n'existe pas.

## Sources de localisation

- GPS via `gpsd`/`gpspipe`, si le materiel le permet.
- Wi-Fi via `nmcli`, pour aider une localisation par bornes internes.
- IP locale et IP publique optionnelle.
- Inventaire Seven Control/Veyon pour la salle, le campus ou la promo.

Sur un PC portable classique, le GPS est souvent absent. Dans ce cas, la localisation exacte n'est pas garantie.

## Serveur

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

## Agent apprenant

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

## Cadre minimum

Avant activation massive:

1. Definir la finalite: securite du parc, perte/vol, support ou inventaire.
2. Informer les apprenants et personnels concernes.
3. Limiter l'acces aux admins autorises.
4. Journaliser chaque consultation admin.
5. Definir une duree de conservation courte.
6. Desactiver la localisation sur les machines hors perimetre.
