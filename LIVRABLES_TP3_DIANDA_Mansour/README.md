                                              Etudiant : DIANDA Mansour


# TP3 — Déployer un canal sécurisé et gérer les certificats

## 1. Présentation

Ce TP consiste à déployer un serveur HTTPS avec Nginx, à configurer TLS 1.2 et TLS 1.3, à mettre en place l'authentification mutuelle (mTLS) et à gérer les certificats numériques.

Les manipulations ont été réalisées localement sur le domaine de laboratoire `www.tp.local`.

## 2. Organisation des livrables

| Fichier / dossier    | Description                                                |
|----------------------|------------------------------------------------------------|
| `nginx-tp3.conf`     | Configuration du serveur HTTPS Nginx.                      |
| `serveur_chaine.crt` | Certificat du serveur et certificat intermédiaire.         |
| `crls.pem`           | Liste des certificats révoqués.                            |
| `racine/racine.crt`  | Certificat public de l'autorité racine.                    |
| `inter/`             | Certificat et base de données de l'autorité intermédiaire. |
| `inter.cnf`          | Configuration de l'autorité intermédiaire.                 |
| `alice.crt`          | Certificat révoqué d'Alice.                                |
| `bob_chain.crt`      | Certificat de Bob accompagné du certificat intermédiaire.  |
| `surveiller.py`      | Script de surveillance de l'expiration des certificats.    | 
| `renouveler.sh`      | Script de renouvellement du certificat serveur.            |

**Confidentialité :** aucune clé privée ni aucun mot de passe n'est fourni dans ces livrables. Les clés nécessaires aux opérations
 de signature et aux tests sont conservées séparément dans l'environnement local de travail. 


## 3. Installation

Les commandes suivantes sont à exécuter depuis le dossier des livrables.

Créer le répertoire TLS :

```bash
sudo mkdir -p /etc/nginx/tls
```

Installer les certificats publics et la CRL :

```bash
sudo install -m 644 serveur_chaine.crt racine/racine.crt crls.pem /etc/nginx/tls/
```

La clé privée du serveur doit être fournie séparément dans l'environnement local, avec les permissions appropriées.

Installer la configuration Nginx :

```bash
sudo cp nginx-tp3.conf /etc/nginx/sites-available/tp3
sudo ln -s /etc/nginx/sites-available/tp3 /etc/nginx/sites-enabled/tp3
```

Ajouter dans `/etc/hosts` :

```text
127.0.0.1 www.tp.local
```

Vérifier et recharger Nginx :

```bash
sudo nginx -t
sudo systemctl reload nginx
```

## 4. Vérifications

### 4.1. Protocoles et suites cryptographiques

```bash
nmap --script ssl-enum-ciphers -p 443 www.tp.local
```

Le résultat attendu présente TLS 1.2 et TLS 1.3, avec des suites cryptographiques AEAD.

### 4.2. Authentification mutuelle

Le test avec un certificat client valide doit aboutir à une réponse HTTP 200.

Le test sans certificat client doit être refusé.

Le certificat révoqué d'Alice doit également être refusé.

Ces tests nécessitent les clés privées correspondantes, conservées séparément dans l'environnement local.

### 4.3. Surveillance des certificats

# Surveiller un certificat
./surveiller.py serveur_chaine.crt

# Surveiller tous les certificats .crt du dossier courant
./surveiller.py .

Codes de retour :

- `0` : certificat valide, au moins 30 jours restants.
- `1` : alerte, moins de 30 jours restants.
- `2` : critique, moins de 7 jours restants.
- `3` : erreur d'utilisation ou de lecture.

### 4.4. Renouvellement du certificat

Tester le processus sans déploiement :

```bash
sudo bash renouveler.sh --test
```

L'exécution nécessite la clé privée de l'autorité intermédiaire, conservée séparément et disponible dans l'environnement local au chemin attendu par le script.

Exécuter le renouvellement normal :

```bash
sudo bash renouveler.sh
```

### 4.5. Programmation automatique

Le renouvellement est prévu quotidiennement à 02 h 00 avec cron.

Exemple de tâche dans `/etc/cron.d/renouveler-certificat` :

```cron
0 2 * * * root /bin/bash /chemin/absolu/vers/renouveler.sh >> /var/log/renouveler-certificat.log 2>&1
```

Le chemin doit être adapté à l'emplacement du script sur la machine.

## 5. Observation avec Wireshark

Les captures ont été réalisées sur l'interface locale `lo`.

**ClientHello :** le client initie la négociation TLS et propose les versions, les suites cryptographiques et le nom du serveur.

**ServerHello :** le serveur sélectionne TLS 1.3, la suite `TLS_AES_256_GCM_SHA384` et le groupe d'échange de clés X25519.

**Données chiffrées :** après ServerHello, les messages suivants de la négociation TLS 1.3 sont chiffrés et apparaissent principalement comme des données chiffrées dans Wireshark.

Les captures d'écran sont présentées dans le compte rendu.

## 6. Questions de réflexion

**1. Pourquoi le certificat racine n'est-il pas envoyé par le serveur ?**

Le certificat racine est déjà connu du client et constitue son ancre de confiance. Le serveur transmet son certificat et le certificat intermédiaire nécessaire à la vérification de la chaîne.

**2. Pourquoi désactiver les tickets de session TLS ?**

La désactivation des tickets évite leur utilisation pour la reprise de session et simplifie la gestion de ces mécanismes.

**3. Quel est l'intérêt de HSTS ?**

HSTS oblige le navigateur à utiliser HTTPS pendant la durée définie. Ici, `max-age=31536000` correspond à une année.

**4. Pourquoi renouveler les certificats avant leur expiration ?**

Le renouvellement anticipé évite les interruptions de service. Le script surveille la durée restante et déclenche le renouvellement
 sous le seuil de 30 jours.

**5. Que se passe-t-il si la chaîne de certification est incomplète ?**

Le client peut ne pas parvenir à construire une chaîne de confiance jusqu'à une autorité racine reconnue. La vérification du
 certificat peut alors échouer.

**6. Quelle procédure suivre en cas de fuite d'une clé privée ?**

Il faut révoquer le certificat associé, publier une CRL actualisée, générer une nouvelle paire de clés et demander un
 nouveau certificat. En cas de compromission d'une autorité de certification, il faut également traiter cette compromission et
 remplacer les certificats concernés.


## 7. Conclusion

Le serveur HTTPS a été configuré avec TLS 1.2 et TLS 1.3. L'authentification mutuelle a été vérifiée avec un certificat client 
valide. Les connexions sans certificat et avec un certificat révoqué ont été rejetées.

Les scripts de surveillance et de renouvellement des certificats ont également été testés.
