# Installation Arch / sevenOS

Ces scripts installent Veyon et les outils Seven Control sur une base Arch Linux ou sevenOS compatible `pacman`.

## 1. Installer les dependances

Depuis la racine du depot:

```bash
./seven-control/arch/install-deps-arch.sh
```

Le script installe les dependances CMake, Qt6, VNC, X11, PAM, LDAP et QCA necessaires au build.

Pour l'interface graphique Qt sur Arch/sevenOS, le paquet `xcb-util-cursor` est egalement installe. Sans lui, Qt peut afficher une erreur du type `Could not load the Qt platform plugin "xcb"`.

## 2. Recuperer les sous-modules

Si le depot n'a pas ete clone avec `--recursive`, lancez:

```bash
git submodule update --init --recursive
```

Le script de build le fait aussi automatiquement, mais cette commande permet de voir les erreurs plus tot.

## 3. Compiler et installer Veyon

```bash
./seven-control/arch/build-install-veyon-arch.sh
```

Par defaut:

- build dans `build-arch`;
- installation dans `/usr`;
- service systemd dans `/usr/lib/systemd/system`;
- Qt6 active;
- traductions desactivees pour accelerer le build local.
- plugin WebAPI desactive par defaut pour eviter les incompatibilites de warnings Qt/GCC recentes; le verrouillage Seven Control n'en a pas besoin.

Pour garder les traductions:

```bash
./seven-control/arch/build-install-veyon-arch.sh --translations
```

Pour compiler sans installer:

```bash
./seven-control/arch/build-install-veyon-arch.sh --no-install
```

Pour activer explicitement le plugin WebAPI:

```bash
./seven-control/arch/build-install-veyon-arch.sh --webapi
```

Si le build echoue dans `plugins/webapi/WebApiHttpServer.cpp` avec `-Werror=sfinae-incomplete`, relancez sans `--webapi`.

## 4. Installer les commandes Seven Control

```bash
./seven-control/install-seven-control.sh
```

Cela installe:

- `/opt/seven-control`;
- `/usr/local/bin/seven-control-lock`;
- `/usr/local/bin/seven-control-import-inventory`.

## 5. Activer le service sur un poste apprenant

Sur chaque machine apprenant:

```bash
sudo systemctl daemon-reload
sudo systemctl enable --now veyon.service
```

Verifiez:

```bash
systemctl status veyon.service
```

## 6. Tester depuis le poste formateur

Importer un inventaire:

```bash
seven-control-import-inventory seven-control/inventory.example.csv --sudo
```

Verrouiller une salle:

```bash
seven-control-lock lock --location Paris-Salle-1
```

Deverrouiller:

```bash
seven-control-lock unlock --location Paris-Salle-1
```

## Interface graphique

Sur sevenOS/Hyprland ou une autre session Wayland, lancez les interfaces via les wrappers Seven Control:

```bash
seven-control-master
seven-control-configurator
```

Ils forcent `QT_QPA_PLATFORM=wayland` lorsque `WAYLAND_DISPLAY` est present, ce qui evite les erreurs `Authorization required` et `could not connect to display :1` liees a X11.

Pour le configurateur, le wrapper utilise `sudo` avec le contexte Wayland conserve, car le `pkexec` interne de Veyon peut perdre l'environnement graphique sur sevenOS/Hyprland. Lancez donc `seven-control-configurator` depuis un terminal.

## Notes sevenOS

Si sevenOS utilise les depots Arch standards, ces scripts devraient fonctionner tels quels. Si certains paquets ont ete renommes, lancez d'abord:

```bash
pacman -Si qt6-base qca-qt6 libvncserver libfakekey
```

Puis ajustez la liste `packages` dans [install-deps-arch.sh](install-deps-arch.sh).
