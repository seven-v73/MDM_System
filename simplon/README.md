# Pack Simplon pour Veyon

Ce dossier ajoute une couche d'exploitation pour utiliser Veyon dans un contexte Simplon:

- inventorier les postes par campus, salle ou promo;
- importer ces postes dans l'annuaire integre Veyon;
- verrouiller ou deverrouiller a distance une salle ou une liste de machines.

Ces outils supposent que Veyon est installe et configure sur des machines administrees par Simplon. Ne les utilisez pas sur des postes personnels ou hors perimetre d'administration.

## Prerequis

1. Installer Veyon Master sur le poste formateur/admin.
2. Installer Veyon Service sur les postes apprenants.
3. Configurer l'authentification par cles Veyon.
4. Ouvrir les ports necessaires entre le poste formateur et les postes apprenants.
5. Verifier que `veyon-cli` fonctionne depuis le poste formateur.

## Inventaire

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
./simplon/import-inventory.sh simplon/inventory.example.csv
```

Le script importe les objets dans l'annuaire integre Veyon via:

```bash
veyon-cli networkobjects import FILE format "%location%;%name%;%host%;%mac%"
```

## Verrouiller une salle

```bash
./simplon/simplon-lock.sh lock --location Paris-Salle-1
```

## Deverrouiller une salle

```bash
./simplon/simplon-lock.sh unlock --location Paris-Salle-1
```

## Verrouiller une liste de machines

```bash
./simplon/simplon-lock.sh lock --hosts hosts.txt
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

## Strategie conseillee

Pour un usage Simplon en production:

1. Demarrer avec l'annuaire integre pour un pilote sur une salle.
2. Basculer ensuite vers LDAP/Active Directory si les postes sont deja geres par un annuaire.
3. Creer des groupes par campus, salle et promo.
4. Restreindre l'acces aux formateurs et administrateurs habilites.
5. Documenter l'usage dans la charte informatique apprenants.
