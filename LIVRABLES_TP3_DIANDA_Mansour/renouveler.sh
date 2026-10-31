#!/bin/bash

# ==========================================================
# RENOUVELLEMENT AUTOMATIQUE DU CERTIFICAT TLS
# Serveur : www.tp.local
# AC : Intermédiaire TP
# ==========================================================

set -Eeuo pipefail

# ----------------------------------------------------------
# 1. CONFIGURATION
# ----------------------------------------------------------

BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$BASE_DIR"

CONFIG_AC="$BASE_DIR/inter.cnf"
CERT_INTER="$BASE_DIR/inter/inter.crt"
CLE_INTER="$BASE_DIR/inter/inter.key"
CERT_RACINE="$BASE_DIR/racine/racine.crt"

CERT_ACTUEL="/etc/nginx/tls/serveur_chaine.crt"
CLE_ACTUELLE="/etc/nginx/tls/serveur.key"

SURVEILLER="$BASE_DIR/surveiller.py"

NOM_SERVEUR="www.tp.local"
DUREE_VALIDITE=90

TEMP_DIR=""
DOSSIER_SAUVEGARDE=""

# ----------------------------------------------------------
# 2. FONCTIONS
# ----------------------------------------------------------

nettoyer() {
    if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
        rm -rf -- "$TEMP_DIR"
    fi
}

restaurer_anciens_fichiers() {

    echo "Restauration de l'ancien certificat..."

    if [[ -z "$DOSSIER_SAUVEGARDE" ||
          ! -f "$DOSSIER_SAUVEGARDE/serveur_chaine.crt" ||
          ! -f "$DOSSIER_SAUVEGARDE/serveur.key" ]]; then
        echo "ERREUR CRITIQUE : sauvegarde introuvable."
        return 1
    fi

    if ! install -m 644 \
        "$DOSSIER_SAUVEGARDE/serveur_chaine.crt" "$CERT_ACTUEL"; then
        echo "ERREUR : restauration du certificat impossible."
        return 1
    fi

    if ! install -m 600 \
        "$DOSSIER_SAUVEGARDE/serveur.key" "$CLE_ACTUELLE"; then
        echo "ERREUR : restauration de la clé impossible."
        return 1
    fi

    if nginx -t && systemctl reload nginx; then
        echo "Ancien certificat restauré avec succès."
        return 0
    fi

    echo "ERREUR CRITIQUE : Nginx nécessite une intervention manuelle."
    return 1
}

# ----------------------------------------------------------
# 3. VÉRIFICATION DES PRÉREQUIS
# ----------------------------------------------------------

echo "=========================================="
echo " RENOUVELLEMENT DU CERTIFICAT TLS"
echo "=========================================="

if [[ "$EUID" -ne 0 ]]; then
    echo "ERREUR : exécuter ce script avec sudo."
    exit 3
fi

for fichier in \
    "$CONFIG_AC" \
    "$CERT_INTER" \
    "$CLE_INTER" \
    "$CERT_RACINE" \
    "$CERT_ACTUEL" \
    "$CLE_ACTUELLE" \
    "$SURVEILLER"; do

    if [[ ! -f "$fichier" ]]; then
        echo "ERREUR : fichier introuvable : $fichier"
        exit 3
    fi
done

for outil in openssl nginx python3 systemctl sha256sum awk; do
    if ! command -v "$outil" >/dev/null 2>&1; then
        echo "ERREUR : outil manquant : $outil"
        exit 3
    fi
done

# ----------------------------------------------------------
# 4. CONTRÔLE DE L'EXPIRATION
# ----------------------------------------------------------

echo "[1/5] Vérification du certificat actuel..."

set +e
python3 "$SURVEILLER" "$CERT_ACTUEL"
CODE_RETOUR=$?
set -e

MODE_TEST=0

if [[ "${1:-}" == "--test" ]]; then
    MODE_TEST=1
elif [[ $# -ne 0 ]]; then
    echo "Utilisation : $0 [--test]"
    exit 3
fi

if [[ "$CODE_RETOUR" -eq 0 && "$MODE_TEST" -eq 0 ]]; then
    echo "Aucun renouvellement nécessaire."
    exit 0
elif [[ "$CODE_RETOUR" -ne 0 && "$CODE_RETOUR" -ne 1 && "$CODE_RETOUR" -ne 2 ]]; then
    echo "ERREUR : impossible de vérifier le certificat."
    exit 3
fi

if [[ "$MODE_TEST" -eq 1 ]]; then
    echo "MODE TEST : renouvellement forcé sans déploiement."
else
    echo "Renouvellement nécessaire."
fi

# ----------------------------------------------------------
# 5. GÉNÉRATION DE LA NOUVELLE CLÉ ET DU CSR
# ----------------------------------------------------------

TEMP_DIR=$(mktemp -d "$BASE_DIR/renouvellement.XXXXXX")
chmod 700 "$TEMP_DIR"

echo "[2/5] Génération de la nouvelle clé privée..."

openssl genpkey \
    -algorithm EC \
    -pkeyopt ec_paramgen_curve:P-256 \
    -out "$TEMP_DIR/serveur.key"

chmod 600 "$TEMP_DIR/serveur.key"

openssl req -new \
    -key "$TEMP_DIR/serveur.key" \
    -out "$TEMP_DIR/serveur.csr" \
    -subj "/C=BF/O=Universite TP/CN=$NOM_SERVEUR" \
    -addext "subjectAltName=DNS:www.tp.local,DNS:tp.local"

echo "Clé privée et CSR générés."

# ----------------------------------------------------------
# 6. SIGNATURE PAR L'AC INTERMÉDIAIRE
# ----------------------------------------------------------

echo "[3/5] Signature du nouveau certificat..."

openssl ca -batch \
    -config "$CONFIG_AC" \
    -extensions ext_serveur \
    -days "$DUREE_VALIDITE" \
    -notext \
    -in "$TEMP_DIR/serveur.csr" \
    -out "$TEMP_DIR/serveur.crt"

echo "Vérification de la chaîne de certification..."

openssl verify \
    -CAfile "$CERT_RACINE" \
    -untrusted "$CERT_INTER" \
    -purpose sslserver \
    -verify_hostname "$NOM_SERVEUR" \
    "$TEMP_DIR/serveur.crt"

# Vérification de la correspondance clé/certificat

EMPREINTE_CLE=$(
    openssl pkey \
        -in "$TEMP_DIR/serveur.key" \
        -pubout -outform DER |
    sha256sum | awk '{print $1}'
)

EMPREINTE_CERT=$(
    openssl x509 \
        -in "$TEMP_DIR/serveur.crt" \
        -pubkey -noout |
    openssl pkey -pubin -outform DER |
    sha256sum | awk '{print $1}'
)

if [[ "$EMPREINTE_CLE" != "$EMPREINTE_CERT" ]]; then
    echo "ERREUR : clé privée et certificat incompatibles."
    exit 1
fi

# Construction de la chaîne complète serveur + intermédiaire

cat "$TEMP_DIR/serveur.crt" "$CERT_INTER" \
    > "$TEMP_DIR/serveur_chaine.crt"

echo "Certificat et chaîne vérifiés."

# ----------------------------------------------------------
# MODE TEST : ARRÊT AVANT LE DÉPLOIEMENT
# ----------------------------------------------------------

if [[ "$MODE_TEST" -eq 1 ]]; then
    echo "=========================================="
    echo " TEST DU RENOUVELLEMENT RÉUSSI"
    echo "=========================================="
    echo "Nouvelle clé privée générée."
    echo "Certificat signé par l'AC intermédiaire."
    echo "Chaîne de certification vérifiée."
    echo "Correspondance clé/certificat vérifiée."
    echo "Aucun fichier Nginx n'a été modifié."

    nettoyer
    exit 0
fi

# ----------------------------------------------------------
# 7. SAUVEGARDE DES ANCIENS FICHIERS
# ----------------------------------------------------------

echo "[4/5] Sauvegarde des anciens fichiers..."

DOSSIER_SAUVEGARDE=$(mktemp -d "/etc/nginx/tls/backup_XXXXXX")
chmod 700 "$DOSSIER_SAUVEGARDE"

cp -p "$CERT_ACTUEL" \
    "$DOSSIER_SAUVEGARDE/serveur_chaine.crt"

cp -p "$CLE_ACTUELLE" \
    "$DOSSIER_SAUVEGARDE/serveur.key"

echo "Sauvegarde créée : $DOSSIER_SAUVEGARDE"

# ----------------------------------------------------------
# 8. INSTALLATION DES NOUVEAUX FICHIERS
# ----------------------------------------------------------

echo "Installation des nouveaux fichiers..."

install -m 644 \
    "$TEMP_DIR/serveur_chaine.crt" "$CERT_ACTUEL.new"

install -m 600 \
    "$TEMP_DIR/serveur.key" "$CLE_ACTUELLE.new"

# Les deux nouveaux fichiers sont prêts.
# On commence maintenant le remplacement des fichiers actifs.

if ! mv -f "$CERT_ACTUEL.new" "$CERT_ACTUEL"; then
    echo "ERREUR : remplacement du certificat impossible."
    exit 1
fi

if ! mv -f "$CLE_ACTUELLE.new" "$CLE_ACTUELLE"; then
    echo "ERREUR : remplacement de la clé impossible."

    if ! restaurer_anciens_fichiers; then
        echo "ATTENTION : intervention manuelle nécessaire."
    fi

    exit 1
fi

echo "Nouveaux fichiers installés."

# ----------------------------------------------------------
# 9. VALIDATION ET RECHARGEMENT DE NGINX
# ----------------------------------------------------------

echo "[5/5] Validation de Nginx..."

if nginx -t && systemctl reload nginx; then

    echo "=========================================="
    echo " RENOUVELLEMENT RÉUSSI"
    echo "=========================================="

    echo "Le nouveau certificat est opérationnel."
    echo "Sauvegarde conservée : $DOSSIER_SAUVEGARDE"

    nettoyer
    exit 0

else

    echo "ERREUR : activation du nouveau certificat impossible."

    if restaurer_anciens_fichiers; then
        echo "Ancien certificat rétabli."
    else
        echo "ATTENTION : intervention manuelle nécessaire."
    fi

    nettoyer
    exit 1
fi
