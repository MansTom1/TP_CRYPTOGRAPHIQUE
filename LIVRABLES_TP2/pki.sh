#!/usr/bin/env bash

# Arrêter le script dès qu'une commande échoue
set -euo pipefail

# Se placer automatiquement dans le répertoire du script
cd "$(dirname "$0")"

# Empêcher l'écrasement d'une infrastructure existante
if [ -f "racine/racine.key" ] || [ -f "inter/inter.key" ]; then
    echo "ERREUR : Une infrastructure PKI existe déjà."
    echo "Supprime ou sauvegarde les anciens fichiers avant de recommencer."
    exit 1
fi


echo "======================================"
echo "   CREATION DE L'INFRASTRUCTURE PKI"
echo "======================================"

# Fonction de création de l'AC racine
creer_ac_racine() {

    echo "[1/4] Création de l'AC racine..."

    # Création de l'arborescence
    mkdir -p racine/{certs,crl,newcerts}

    # Initialisation de la base de données
    touch racine/index.txt

    echo 1000 > racine/serial
    echo 1000 > racine/crlnumber

    # Génération de la clé privée EC P-384
    openssl genpkey -algorithm EC \
        -pkeyopt ec_paramgen_curve:P-384 \
        -out racine/racine.key

    # Création du certificat racine auto-signé
    openssl req -x509 -new \
        -key racine/racine.key \
        -sha384 \
        -days 3650 \
        -subj "/C=BF/O=Universite TP/CN=Racine TP" \
        -addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
        -addext "keyUsage=critical,keyCertSign,cRLSign" \
        -addext "subjectKeyIdentifier=hash" \
        -out racine/racine.crt

    echo "AC racine créée avec succès."
}


# Fonction de création de l'AC intermédiaire
creer_ac_intermediaire() {

    echo "[2/4] Création de l'AC intermédiaire..."

    # Création de l'arborescence
    mkdir -p inter/{certs,crl,newcerts}

    # Initialisation de la base de données
    touch inter/index.txt

    echo 2000 > inter/serial
    echo 2000 > inter/crlnumber
    echo "unique_subject = yes" > inter/index.txt.attr

    # Génération de la clé privée EC P-256
    openssl genpkey -algorithm EC \
        -pkeyopt ec_paramgen_curve:P-256 \
        -out inter/inter.key

    # Création de la demande de certificat (CSR)
    openssl req -new \
        -key inter/inter.key \
        -subj "/C=BF/O=Universite TP/CN=AC Intermediaire TP" \
        -out inter/inter.csr

    # Signature du certificat par l'AC racine
    openssl ca -batch \
        -config racine.cnf \
        -name ca_racine \
        -extensions ext_inter \
        -policy politique_souple \
        -in inter/inter.csr \
        -out inter/inter.crt \
        -notext \
        -days 1825

    echo "AC intermédiaire créée avec succès."
}


# Fonction de création du certificat serveur
creer_certificat_serveur() {

    echo "[3/4] Création du certificat serveur..."

    # Génération de la clé privée EC P-256
    openssl genpkey -algorithm EC \
        -pkeyopt ec_paramgen_curve:P-256 \
        -out serveur.key

    # Création de la demande de certificat (CSR)
    openssl req -new \
        -key serveur.key \
        -subj "/CN=www.tp.local" \
        -addext "subjectAltName=DNS:www.tp.local,DNS:tp.local" \
        -out serveur.csr

    # Signature du certificat par l'AC intermédiaire
    openssl ca -batch \
        -config inter.cnf \
        -extensions ext_serveur \
        -days 90 \
        -in serveur.csr \
        -out serveur.crt

    echo "Certificat serveur créé avec succès."
}

# Fonction de création du certificat client
creer_certificat_client() {

    echo "[4/4] Création du certificat client..."

    # Génération de la clé privée EC P-256
    openssl genpkey -algorithm EC \
        -pkeyopt ec_paramgen_curve:P-256 \
        -out alice.key

    # Création de la demande de certificat (CSR)
    openssl req -new \
        -key alice.key \
        -subj "/CN=alice@tp.local" \
        -out alice.csr

    # Signature du certificat par l'AC intermédiaire
    openssl ca -batch \
        -config inter.cnf \
        -extensions ext_client \
        -days 90 \
        -in alice.csr \
        -out alice.crt

    echo "Certificat client créé avec succès."
}


# Exécution des différentes étapes
creer_ac_racine
creer_ac_intermediaire
creer_certificat_serveur
creer_certificat_client

echo "======================================"
echo "   INFRASTRUCTURE PKI CREEE AVEC SUCCES"
echo "======================================"
