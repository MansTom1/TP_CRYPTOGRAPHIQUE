#!/usr/bin/env python3

import sys
import subprocess
from pathlib import Path
from datetime import datetime, timezone


def obtenir_date_expiration(certificat):
    resultat = subprocess.run(
        ["openssl", "x509", "-in", str(certificat), "-noout", "-enddate"],
        capture_output=True,
        text=True,
        check=True
    )

    date_expiration = resultat.stdout.strip().split("=", 1)[1]

    return datetime.strptime(
        date_expiration,
        "%b %d %H:%M:%S %Y %Z"
    ).replace(tzinfo=timezone.utc)


def calculer_jours_restants(certificat):
    date_expiration = obtenir_date_expiration(certificat)
    date_actuelle = datetime.now(timezone.utc)
    difference = date_expiration - date_actuelle

    return difference.days


def afficher_etat(certificat, jours):
    if jours < 7:
        print(f"CRITIQUE : {certificat} expire dans {jours} jour(s).")
        return 2

    elif jours < 30:
        print(f"ALERTE : {certificat} expire dans {jours} jour(s).")
        return 1

    else:
        print(f"OK : {certificat} est valide encore {jours} jour(s).")
        return 0


def main():
    if len(sys.argv) != 2:
        print(f"Utilisation : {sys.argv[0]} <certificat.pem|dossier>")
        sys.exit(3)

    chemin = Path(sys.argv[1])

    if chemin.is_file():
        certificats = [chemin]

    elif chemin.is_dir():
        certificats = sorted(chemin.glob("*.crt"))

    else:
        print("ERREUR : fichier ou dossier introuvable.")
        sys.exit(3)

    if not certificats:
        print("ERREUR : aucun certificat .crt trouvé.")
        sys.exit(3)

    code_global = 0

    for certificat in certificats:
        try:
            jours = calculer_jours_restants(certificat)
            code = afficher_etat(certificat, jours)
            code_global = max(code_global, code)

        except (subprocess.CalledProcessError, FileNotFoundError, ValueError, IndexError) as erreur:
            print(f"ERREUR : impossible de lire {certificat} : {erreur}")
            code_global = 3

    sys.exit(code_global)


if __name__ == "__main__":
    main()
