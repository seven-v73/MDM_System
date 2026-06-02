# Runbook Seven Control - usage massif

Ce runbook decrit la procedure conseillee pour utiliser Veyon/Seven Control sur un parc important.

## Objectif

Permettre a un formateur ou administrateur habilite de:

- verifier les postes d'une salle ou promo;
- verrouiller ou deverrouiller rapidement un lot de machines;
- conserver une trace des actions;
- eviter de saturer le reseau ou le poste Master.

## Avant chaque changement important

Sauvegarder la configuration:

```bash
seven-control-backup-config --sudo
```

Valider l'inventaire:

```bash
seven-control-validate-inventory seven-control/inventory.example.csv
```

Importer:

```bash
seven-control-import-inventory seven-control/inventory.example.csv --sudo
```

Appliquer le profil massif:

```bash
seven-control-apply-profile --sudo --massive
```

## Avant une action sur une salle

Verifier la joignabilite:

```bash
seven-control-health-check --location Paris-Salle-1 --parallel 32 --timeout 2
```

Si moins de 90% des postes sont joignables, traiter d'abord:

- service Veyon non demarre;
- machine eteinte;
- IP/DNS incorrect;
- firewall;
- poste hors reseau.

## Verrouillage progressif

Toujours commencer par un dry-run:

```bash
seven-control-lock lock --location Paris-Salle-1 --dry-run
```

Puis lancer avec parallellisme faible:

```bash
seven-control-lock lock --location Paris-Salle-1 --parallel 8 --timeout 45 --retries 1 --log-file seven-control-lock-paris-s1.csv
```

Si tout est stable, monter a 16:

```bash
seven-control-lock lock --location Paris-Salle-1 --parallel 16 --timeout 45 --retries 1 --log-file seven-control-lock-paris-s1.csv
```

## Deverrouillage

```bash
seven-control-lock unlock --location Paris-Salle-1 --parallel 16 --timeout 45 --retries 1 --log-file seven-control-unlock-paris-s1.csv
```

## Seuils conseilles

- Salle de 10 a 30 postes: `--parallel 8`
- Salle de 30 a 60 postes: `--parallel 16`
- Plusieurs salles: traiter salle par salle
- Campus entier: eviter au debut; utiliser LDAP/AD et lots controles

## Limites connues

- Le verrouillage via CLI ouvre une connexion par machine.
- Les machines eteintes ou injoignables consomment du temps jusqu'au timeout.
- Le monitoring graphique massif consomme beaucoup plus que le verrouillage.
- L'annuaire CSV integre est utile pour un pilote; LDAP/AD est preferable pour un parc vivant.

## Production recommandee

- Authentification par cles Veyon.
- Groupes dedies `seven-control-formateurs` et `seven-control-admins`.
- LDAP/AD pour machines, salles, promos.
- Journalisation avec rotation.
- Tests de joignabilite avant action.
- Operations par salle/promo, jamais "tout le parc" sans test prealable.
