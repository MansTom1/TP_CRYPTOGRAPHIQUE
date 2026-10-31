                                    Etudiant : DIANDA Mansour

# TP2 — Construire une infrastructure de gestion de clés (PKI)

## 1. Objectif du TP

Ce TP consiste à construire une infrastructure de gestion de clés (PKI) avec OpenSSL.

L'infrastructure comprend :
- Une autorité de certification racine (AC racine).
- Une autorité de certification intermédiaire.
- Un certificat serveur pour `www.tp.local`.
- Un certificat client pour `alice@tp.local`.
- Des listes de révocation de certificats (CRL).

## 2. Environnement de travail

- Système d'exploitation : Ubuntu 24.04 LTS
- Outil : OpenSSL
- Langage de script : Bash
- Algorithmes de clés : courbes elliptiques P-384 et P-256

## 3. Organisation des fichiers

L'arborescence utilisée est la suivante :

```text
TP2_CRYPTOGRAPHIE/
├── racine/
│   ├── certs/
│   ├── crl/
│   │   └── racine.crl
│   ├── newcerts/
│   ├── index.txt
│   ├── crlnumber
│   ├── serial
│   ├── racine.crt
│   └── racine.key
├── inter/
│   ├── certs/
│   ├── crl/
│   │   └── inter.crl
│   ├── newcerts/
│   ├── index.txt
│   ├── crlnumber
│   ├── serial
│   ├── inter.crt
│   ├── inter.csr
│   ├── inter.key
│   └── inter-ancien.crt
├── racine.cnf
├── inter.cnf
├── serveur.csr
├── serveur.crt
├── serveur.key
├── alice.csr
├── alice.crt
├── alice.key
├── interdit.csr
├── interdit.crt
├── interdit.key
├── crl-completes.pem
├── pki.sh
└── README.md
```
## 4. Étape 1 — Préparer les autorités
### 4.1. Fichier `racine.cnf`

Ce fichier contient les paramètres de l'AC racine.



La section `[ politique_souple ]` définit les informations obligatoires dans les demandes :
- `countryName = optional` : le pays est facultatif.
- `organizationName = optional` : l'organisation est facultative.
- `commonName = supplied` : le nom commun doit être fourni.

### 4.2. Section des extensions de l'AC intermédiaire

```ini
[ ext_inter ]
basicConstraints = critical,CA:TRUE,pathlen:0
keyUsage = critical,keyCertSign,cRLSign
nameConstraints = critical,@contraintes_noms
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
```

| Ligne                                           | Rôle                                                |
|-------------------------------------------------|-----------------------------------------------------|
| `basicConstraints = critical,CA:TRUE,pathlen:0` | Indique que le certificat appartient à une AC et qu'elle ne peut pas créer d'autre AC intermédiaire. |
| `keyUsage = critical,keyCertSign,cRLSign`       | Autorise la signature des certificats et des listes de révocation. |
| `nameConstraints = critical,@contraintes_noms`  | Limite les noms autorisés selon les règles définies dans la section `contraintes_noms`. |
| `subjectKeyIdentifier = hash`                   | Ajoute un identifiant calculé à partir de la clé publique. |
| `authorityKeyIdentifier = keyid`                | Identifie la clé de l'autorité ayant signé le certificat. |

La section des contraintes de noms est définie ainsi :

```ini
[contraintes_noms]
permitted;DNS.1 = .tp.local
permitted;DNS.2 = tp.local
permitted;email.1 = tp.local
```

Ces lignes limitent les noms autorisés au domaine `tp.local` et à ses sous-domaines, pour les noms DNS et les adresses électroniques.

### 4.3. Fichier `inter.cnf`

Ce fichier contient les paramètres de l'AC intermédiaire.


La section `[ politique_souple ]` utilise les mêmes règles que celle de l'AC racine : le pays et l'organisation sont facultatifs, tandis que le nom commun est obligatoire.

### 4.4. Extensions du certificat serveur

```ini
[ ext_serveur ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = serverAuth
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
```

| Ligne                                  | Rôle                                                       |
|----------------------------------------|------------------------------------------------------------|
| `basicConstraints = critical,CA:FALSE` | Indique que le certificat n'est pas un certificat d'autorité de certification. |
| `keyUsage = critical,digitalSignature` | Autorise l'utilisation de la clé pour vérifier les signatures numériques. |
| `extendedKeyUsage = serverAuth`        | Destine le certificat à l'authentification d'un serveur.   |
| `subjectKeyIdentifier = hash`          | Ajoute un identifiant calculé à partir de la clé publique. |
| `authorityKeyIdentifier = keyid`       | Identifie la clé de l'autorité ayant signé le certificat.  |

### 4.5. Extensions du certificat client

```ini
[ ext_client ]
basicConstraints = critical,CA:FALSE
keyUsage = critical,digitalSignature
extendedKeyUsage = clientAuth
subjectAltName = email:alice@tp.local
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid
```

| Ligne                                   | Rôle                                                       |
|-----------------------------------------|------------------------------------------------------------|
| `basicConstraints = critical,CA:FALSE`  | Indique que le certificat n'est pas un certificat d'autorité de certification. |
| `keyUsage = critical,digitalSignature`  | Autorise l'utilisation de la clé pour vérifier les signatures numériques. |
| `extendedKeyUsage = clientAuth`         | Destine le certificat à l'authentification d'un client.    |
| `subjectAltName = email:alice@tp.local` | Définit l'adresse électronique d'Alice comme nom alternatif. |
| `subjectKeyIdentifier = hash`           | Ajoute un identifiant calculé à partir de la clé publique. |
| `authorityKeyIdentifier = keyid`        | Identifie la clé de l'autorité ayant signé le certificat.  |

## 5. Étape 2 — Créer l'AC racine

### 5.1. Génération de la clé privée

```bash
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-384 -out racine/racine.key
```

Cette commande génère la clé privée de l'AC racine sur la courbe elliptique P-384.

### 5.2. Création du certificat racine

```bash
openssl req -x509 -new -key racine/racine.key -sha384 -days 3650 \
-subj "/C=BF/O=Universite TP/CN=Racine TP" \
-addext "basicConstraints=critical,CA:TRUE,pathlen:1" \
-addext "keyUsage=critical,keyCertSign,cRLSign" \
-addext "subjectKeyIdentifier=hash" -out racine/racine.crt
```

Cette commande crée un certificat racine auto-signé d'une durée de validité de 10 ans.

### 5.3. Vérification du certificat

```bash
openssl x509 -in racine/racine.crt -noout -text
```

La vérification permet d'observer le sujet, l'émetteur, la période de validité, l'algorithme de clé et les extensions.



## 6. Étape 3 — Créer l'AC intermédiaire

### 6.1. Génération de la clé privée

```bash
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out inter/inter.key
```

### 6.2. Création de la demande de certificat

```bash
openssl req -new -key inter/inter.key \
-subj "/C=BF/O=Universite TP/CN=AC Intermediaire TP" \
-out inter/inter.csr
```

### 6.3. Signature par l'AC racine

```bash
openssl ca -batch -config racine.cnf -extensions ext_inter -days 1825 \
-in inter/inter.csr -out inter/inter.crt
```

Cette commande permet à l'AC racine de signer le certificat de l'AC intermédiaire pour une durée de 5 ans.



## 7. Étape 4 — Créer les certificats serveur et client

### 7.1. Certificat du serveur

#### Génération de la clé privée

```bash
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out serveur.key
```

#### Création de la demande de certificat

```bash
openssl req -new -key serveur.key -subj "/CN=www.tp.local" \
-addext "subjectAltName=DNS:www.tp.local,DNS:tp.local" -out serveur.csr
```

#### Signature par l'AC intermédiaire

```bash
openssl ca -batch -config inter.cnf -extensions ext_serveur -days 90 \
-in serveur.csr -out serveur.crt
```

Le certificat serveur est délivré pour une durée de 90 jours.

### 7.2. Certificat du client Alice

#### Génération de la clé privée

```bash
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out alice.key
```

#### Création de la demande de certificat

```bash
openssl req -new -key alice.key -subj "/CN=alice@tp.local" -out alice.csr
```

#### Signature par l'AC intermédiaire

```bash
openssl ca -batch -config inter.cnf -extensions ext_client -days 90 \
-in alice.csr -out alice.crt
```

Le certificat client est délivré pour une durée de 90 jours.

## 8. Étape 5 — Vérifier la chaîne et les contraintes

### 8.1. Vérification du certificat serveur

```bash
openssl verify -CAfile racine/racine.crt \
-untrusted inter/inter.crt \
-verify_hostname www.tp.local serveur.crt
```

Résultat obtenu :

```text
serveur.crt: OK
```

La chaîne de certification et le nom d'hôte sont correctement vérifiés.

### 8.2. Vérification avec un nom d'hôte incorrect

La vérification avec le nom `autre.example` échoue avec une erreur de correspondance du nom d'hôte.

### 8.3. Vérification du certificat client

```bash
openssl verify -CAfile racine/racine.crt \
-untrusted inter/inter.crt -purpose sslclient alice.crt
```

Résultat obtenu :

```text
alice.crt: OK
```

Le certificat client est valide pour l'authentification d'un client.

### 8.4. Vérification des contraintes de noms

Un certificat pour `www.example.com` a été créé afin de vérifier le respect des contraintes de noms.

```bash
openssl genpkey -algorithm EC -pkeyopt ec_paramgen_curve:P-256 -out interdit.key

openssl req -new -key interdit.key -subj "/CN=www.example.com" \
-addext "subjectAltName=DNS:www.example.com" -out interdit.csr

openssl ca -batch -config inter.cnf -extensions ext_serveur -days 90 \
-in interdit.csr -out interdit.crt
```

Vérification :

```bash
openssl verify -CAfile racine/racine.crt \
-untrusted inter/inter.crt interdit.crt
```

Résultat obtenu : erreur `permitted subtree violation`.

Le certificat est refusé parce que le nom `www.example.com` ne respecte pas les contraintes de noms définies dans le certificat de l'AC intermédiaire.

**Question : Pourquoi l'AC a-t-elle pu signer ce certificat alors qu'il est refusé à la validation ?**

Réponse : La signature du certificat par l'AC ne garantit pas à elle seule que toutes les conditions de validation sont respectées. La vérification de la chaîne contrôle également les contraintes de noms. Le nom `www.example.com` étant en dehors du domaine autorisé `tp.local`, le certificat est rejeté.

## 9. Étape 6 — Révoquer les certificats

La clé privée d'Alice étant supposée compromise, son certificat doit être révoqué.

### 9.1. Révocation du certificat d'Alice

```bash
openssl ca -config inter.cnf -revoke alice.crt -crl_reason keyCompromise
```

Le certificat d'Alice est révoqué avec le motif `Key Compromise`.

### 9.2. Génération de la CRL de l'AC intermédiaire

```bash
openssl ca -config inter.cnf -gencrl -out inter/crl/inter.crl
```

Vérification :

```bash
openssl crl -in inter/crl/inter.crl -noout -text
```

La CRL contient le numéro de série du certificat d'Alice et le motif de révocation `Key Compromise`.

### 9.3. Génération de la CRL de l'AC racine

```bash
openssl ca -config racine.cnf -gencrl -out racine/crl/racine.crl
```

Cette CRL contient notamment l'ancien certificat intermédiaire révoqué avec le motif `Superseded`.

### 9.4. Vérification du certificat révoqué

```bash
openssl verify -CAfile racine/racine.crt \
-untrusted inter/inter.crt \
-CRLfile inter/crl/inter.crl -crl_check alice.crt
```

Résultat attendu et obtenu : erreur `certificate revoked`.

### 9.5. Vérification de l'ancien certificat intermédiaire

```bash
openssl verify -CAfile racine/racine.crt \
-CRLfile racine/crl/racine.crl -crl_check inter/inter-ancien.crt
```

Résultat obtenu : erreur `certificate revoked`.

### 9.6. Regroupement des CRL

```bash
cat racine/crl/racine.crl inter/crl/inter.crl > crl-completes.pem
```

### 9.7. Vérification complète de la révocation

```bash
openssl verify -CAfile racine/racine.crt \
-untrusted inter/inter.crt \
-CRLfile crl-completes.pem \
-crl_check_all serveur.crt
```

Résultat obtenu :

```text
serveur.crt: OK
```

Le certificat serveur est valide et n'est pas révoqué.

## 10. Étape 7 — Automatiser avec `pki.sh`

Le script `pki.sh` automatise uniquement les étapes suivantes :

- Étape 2 : création de l'AC racine.
- Étape 3 : création de l'AC intermédiaire.
- Étape 4 : création des certificats serveur et client.

Le script utilise :

```bash
set -euo pipefail
```

Cette directive permet d'arrêter l'exécution en cas d'erreur.

Une protection empêche également l'écrasement d'une infrastructure PKI déjà créée.

Le script a été vérifié avec :

```bash
bash -n pki.sh
```

Puis rendu exécutable avec :

```bash
chmod +x pki.sh
```

## 11. Questions de réflexion

### Question 1

**Pourquoi la clé de la racine doit-elle rester hors ligne ? Que faut-il faire si l'intermédiaire est compromis ? Et la racine ?**

Réponse :

La clé privée de l'AC racine doit rester hors ligne afin de réduire les risques de vol ou d'utilisation non autorisée.

Si l'AC intermédiaire est compromise, il faut révoquer son certificat avec l'AC racine, générer une nouvelle clé pour l'intermédiaire et lui délivrer un nouveau certificat.

Si l'AC racine est compromise, il faut considérer toute l'infrastructure comme compromise, remplacer la racine et reconstruire la chaîne de confiance.

### Question 2

**À quoi sert `pathlen:0` sur l'intermédiaire ? Quel risque si on l'oublie ?**

Réponse :

`pathlen:0` interdit à l'AC intermédiaire de délivrer des certificats à d'autres autorités de certification intermédiaires. Si cette limite est oubliée, la hiérarchie de certification pourrait être étendue au-delà de ce qui est prévu.

### Question 3

**Pourquoi la clé privée du serveur est-elle générée par le serveur et non par l'AC ?**

Réponse :

La clé privée doit rester sous le contrôle du serveur. Si l'AC la génère, elle connaît cette clé et peut potentiellement l'utiliser. La génération locale garantit que la clé privée ne quitte pas le serveur.

### Question 4

**Le nom commun (CN) du certificat et le champ des noms alternatifs (SAN) contiennent tous deux `www.tp.local`. Lequel les clients modernes vérifient-ils ?**

Réponse :

Les clients modernes vérifient principalement le champ SAN (Subject Alternative Name). Le CN n'est plus la référence utilisée pour la vérification des noms d'hôte.

### Question 5

**Quelles sont les limites des CRL ? Comparer avec OCSP et avec des certificats de très courte durée.**

Réponse :

Les CRL peuvent être volumineuses et ne sont pas toujours actualisées immédiatement. Leur téléchargement peut également prendre du temps.

OCSP permet de vérifier directement l'état d'un certificat auprès d'un serveur de statut. Cependant, il dépend de la disponibilité de ce serveur et peut poser des questions de confidentialité.

Les certificats de très courte durée réduisent la période pendant laquelle un certificat compromis peut être utilisé. Ils limitent ainsi la dépendance à la révocation, à condition que leur renouvellement soit automatisé.

### Question 6

**Rédiger en dix lignes une politique de certification minimale pour cette infrastructure.**

Réponse :

1. Les utilisateurs autorisés de l'infrastructure peuvent demander un certificat.
2. Chaque demandeur doit fournir une identité vérifiable.
3. Les serveurs doivent démontrer le contrôle du nom de domaine demandé.
4. Les certificats serveur sont délivrés uniquement pour les domaines autorisés.
5. Les certificats client sont associés à une adresse électronique vérifiée.
6. Les clés privées sont générées et conservées par leurs propriétaires.
7. L'AC intermédiaire signe les certificats après vérification des demandes.
8. Les certificats serveur et client ont une durée de validité de 90 jours.
9. Tout certificat dont la clé privée est compromise doit être révoqué.
10. Les CRL sont générées et publiées afin de permettre la vérification des révocations.

## 12. Livrables

- Le script `pki.sh`.
- Le fichier de configuration `racine.cnf`.
- Le fichier de configuration `inter.cnf`.
- Les certificats publics générés.
- Le compte rendu de trois pages.


