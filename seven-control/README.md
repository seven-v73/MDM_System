# Seven Control

Seven Control est une couche d'exploitation pour piloter un parc de postes apprenants avec Veyon comme moteur technique:

- inventorier les postes par campus, salle ou promo;
- importer ces postes dans l'annuaire integre Veyon;
- verrouiller ou deverrouiller a distance une salle ou une liste de machines.

Ces outils supposent que Veyon est installe et configure sur des machines administrees par votre organisation. Ne les utilisez pas sur des postes personnels ou hors perimetre d'administration.

## Prerequis

1. Installer Veyon Master sur le poste formateur/admin.
2. Installer Veyon Service sur les postes apprenants.
3. Configurer l'authentification par cles Veyon.
4. Ouvrir les ports necessaires entre le poste formateur et les postes apprenants.
5. Verifier que `veyon-cli` fonctionne depuis le poste formateur.

## Installation Arch / sevenOS

Pour une machine Arch Linux ou sevenOS base Arch, utilisez le guide dedie:

```bash
./seven-control/arch/install-deps-arch.sh
./seven-control/arch/build-install-veyon-arch.sh
./seven-control/install-seven-control.sh
```

Details: [arch/README.md](arch/README.md).

## Inventaire

Avant d'utiliser l'inventaire integre, appliquez le profil Seven Control de base:

```bash
seven-control-apply-profile --sudo
```

Pour un parc important, appliquez le profil massif:

```bash
seven-control-apply-profile --sudo --massive
```

Il selectionne l'annuaire integre Veyon et le backend de groupes utilisateurs systeme.

Validez toujours l'inventaire avant import massif:

```bash
seven-control-validate-inventory seven-control/inventory.example.csv
```

Sauvegardez la configuration avant une modification importante:

```bash
seven-control-backup-config --sudo
```

Le fichier [inventory.example.csv](inventory.example.csv) utilise un format CSV a separateur `;`:

```csv
location;name;host;mac
Paris-Salle-1;PAR-S1-PC01;192.168.10.21;AA:BB:CC:DD:EE:01
```

- `location`: salle, campus ou promo.
- `name`: nom lisible du poste.
- `host`: IP ou nom DNS joignable.
- `mac`: adresse MAC, utile pour certaines fonctions d'administration.

## Importer les machines

Depuis la racine du projet ou depuis une installation contenant `veyon-cli`:

```bash
./seven-control/import-inventory.sh seven-control/inventory.example.csv
```

Sur Arch/sevenOS, l'import modifie la configuration systeme Veyon. Si vous voyez `Configuration is not writable`, relancez avec:

```bash
seven-control-import-inventory seven-control/inventory.example.csv --sudo
```

Le mode `--sudo` force l'import en mode Qt non graphique pour eviter les erreurs d'acces au display sous `sudo`.

Le script importe les objets dans l'annuaire integre Veyon via:

```bash
veyon-cli networkobjects import FILE format "%location%;%name%;%host%;%mac%"
```

## Verrouiller une salle

```bash
./seven-control/seven-control-lock.sh lock --location Paris-Salle-1
```

Pour un usage massif, utilisez un parallellisme controle:

```bash
seven-control-lock lock --location Paris-Salle-1 --parallel 16
```

Commencez avec `--parallel 8` ou `--parallel 16`, puis augmentez progressivement selon le reseau et la stabilite des postes.

Pour auditer une operation:

```bash
seven-control-lock lock --location Paris-Salle-1 --parallel 16 --timeout 45 --retries 1 --log-file seven-control-lock.csv
```

Avant une action massive, verifiez la joignabilite:

```bash
seven-control-health-check --location Paris-Salle-1
```

## Deverrouiller une salle

```bash
./seven-control/seven-control-lock.sh unlock --location Paris-Salle-1
```

## Verrouiller une liste de machines

```bash
./seven-control/seven-control-lock.sh lock --hosts hosts.txt
```

`hosts.txt` doit contenir une IP ou un nom DNS par ligne. Les lignes vides et celles commencant par `#` sont ignorees.

## Verification rapide

Lister les fonctionnalites disponibles:

```bash
veyon-cli feature list
```

Tester un verrouillage sur une seule machine:

```bash
veyon-cli feature start 192.168.10.21 ScreenLock
veyon-cli feature stop 192.168.10.21 ScreenLock
```

## Interface graphique

Sur Arch/sevenOS en session Wayland, utilisez les lanceurs Seven Control:

```bash
seven-control-master
seven-control-configurator
```

Ces lanceurs forcent automatiquement `QT_QPA_PLATFORM=wayland` quand une session Wayland est detectee.

`seven-control-configurator` contourne aussi les soucis `pkexec`/Wayland en lancant le configurateur avec `sudo` et le bon environnement graphique. Lancez-le depuis un terminal pour pouvoir saisir le mot de passe admin.

Verifier le wrapper installe:

```bash
seven-control-configurator --version
```

La sortie doit contenir `admin-wayland`.

## Strategie conseillee

Pour un usage Seven Control en production:

1. Demarrer avec l'annuaire integre pour un pilote sur une salle.
2. Basculer ensuite vers LDAP/Active Directory si les postes sont deja geres par un annuaire.
3. Creer des groupes par campus, salle et promo.
4. Restreindre l'acces aux formateurs et administrateurs habilites.
5. Documenter l'usage dans la charte informatique apprenants.

Pour les operations sur de grands lots, voir [RUNBOOK-MASSIF.md](RUNBOOK-MASSIF.md).
