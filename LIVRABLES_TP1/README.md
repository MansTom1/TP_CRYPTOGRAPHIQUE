                                Etudiant : DIANDA Mansour

# TP1 — Mini-coffre-fort cryptographique


## 1. Présentation du projet

Ce projet consiste à développer en Python un mini-coffre-fort cryptographique permettant de chiffrer des données et de les déchiffrer à l'aide d'un mot de passe.

L'objectif est de mettre en pratique plusieurs mécanismes de cryptographie moderne :

- **Argon2id   ** : dérivation d'une clé à partir d'un mot de passe.
- **HKDF-SHA256** : dérivation d'une sous-clé cryptographique.
- **AES-256-GCM** : chiffrement des données et vérification de leur intégrité.
- **  pytest   ** : exécution des tests automatisés.

Le projet utilise un format de données versionné appelé `CFR1`.



## 2. Organisation des fichiers

Le dossier du projet contient les éléments suivants :

| Fichier ou dossier    |          Rôle                                                             |
|-----------------------|---------------------------------------------------------------------------|
|   `coffre.py`         | Contient les fonctions cryptographiques du mini-coffre-fort.              | 
|   `test_coffre.py`    | Contient les tests automatisés des fonctions.                             |
|   `.tpcryptographie/` | Environnement virtuel Python contenant les dépendances du projet.         |
|   `README.md`         | Présente le projet, son fonctionnement et les instructions d'utilisation. |

Les dossiers `__pycache__/`  et  `.pytest_cache/` sont générés automatiquement par Python et pytest.




## 3. Prérequis

Pour exécuter le projet, il faut disposer de :

- Python 3 ;
- pip ;
- un terminal ;
- les bibliothèques `argon2-cffi`, `cryptography` et `pytest`.

Le projet a été développé et testé sous Ubuntu.




## 4. Installation et préparation de l'environnement

### 4.1. Se placer dans le dossier du projet

```bash
cd ~/Desktop/TP1_CRYPTOGRAPHIE
```


### 4.2. Créer un environnement virtuel

Si l'environnement virtuel n'existe pas encore :

```bash
python3 -m venv .tpcryptographie
```


### 4.3. Activer l'environnement virtuel

```bash
source .tpcryptographie/bin/activate
```

Le nom de l'environnement virtuel apparaît normalement au début de l'invite du terminal.



### 4.4. Installer les dépendances

```bash
python -m pip install argon2-cffi cryptography pytest
```

Ces bibliothèques servent respectivement à utiliser Argon2id, les primitives cryptographiques et les tests automatisés.



## 5. Paramètres cryptographiques

Les paramètres retenus pour Argon2id sont :

```python
T, M, P = 30, 64 * 1024, 4
```

Signification :

- `T = 30` : nombre de passes d'Argon2id ;
- `M = 65536 KiB` : mémoire utilisée, soit 64 Mio ;
- `P = 4` : degré de parallélisme.

Une mesure réalisée sur la machine de développement a donné les résultats suivants :

|  T | Mémoire   |  P  | Temps médian mesuré |
|----|-----------|-----|---------------------|
|  3 | 65536 KiB |  4  |       0,074 s       |
| 10 | 65536 KiB |  4  |       0,183 s       |
| 15 | 65536 KiB |  4  |       0,253 s       |
| 20 | 65536 KiB |  4  |       0,344 s       |
| 25 | 65536 KiB |  4  |       0,415 s       |
| 28 | 65536 KiB |  4  |       0,468 s       |
| 30 | 65536 KiB |  4  |       0,494 s       |

Le paramètre `T = 30` a été retenu parce que le temps médian mesuré, environ 0,494 seconde, est proche de l'objectif de 0,5 seconde.

Ces résultats dépendent du matériel et de l'environnement d'exécution.

La fonction `valider_parametres_argon2()` contrôle les valeurs autorisées avant que les paramètres enregistrés dans l'en-tête soient utilisés lors du déchiffrement. La limite maximale du paramètre temporel doit donc être cohérente avec la valeur retenue, ici `30`.




## 6. Explication des fonctions de `coffre.py`

### 6.1. `valider_parametres_argon2()`

Cette fonction vérifie que les paramètres Argon2id respectent les limites prévues par le programme.

Elle contrôle :

- le nombre de passes ;
- la quantité de mémoire ;
- le parallélisme ;
- la cohérence entre la mémoire et le parallélisme.

Si un paramètre est interdit, la fonction lève une exception `ValueError`.

Cette validation est importante parce que les paramètres sont enregistrés dans l'en-tête du fichier chiffré. Elle évite notamment qu'un fichier malveillant impose des paramètres de dérivation excessivement coûteux.

### 6.2. `cle_maitresse()`

Cette fonction dérive une clé maîtresse à partir d'un mot de passe et d'un sel.

Le mot de passe est converti en octets avec UTF-8, puis traité par Argon2id.

La clé maîtresse produite fait 32 octets, soit 256 bits.

Le sel est généré aléatoirement lors du chiffrement. Il n'a pas besoin d'être secret.




### 6.3. `sous_cle()`

Cette fonction utilise HKDF avec SHA-256 pour dériver une sous-clé de 32 octets à partir de la clé maîtresse.

Le paramètre `usage` permet d'identifier la destination de la sous-clé.

Dans ce projet, la valeur `b"chiffrement"` identifie la sous-clé destinée au chiffrement.

Cette séparation des usages facilite l'évolution du programme et évite d'utiliser directement la clé maîtresse pour toutes les opérations.




### 6.4. `chiffrer()`

Cette fonction chiffre les données avec un mot de passe.

Elle effectue les opérations suivantes :

1. Génère un sel aléatoire de 16 octets.
2. Génère un nonce aléatoire de 12 octets.
3. Prépare l'en-tête du fichier.
4. Dérive la clé maîtresse avec Argon2id.
5. Dérive la sous-clé de chiffrement avec HKDF-SHA256.
6. Construit les données associées authentifiées, ou AAD.
7. Chiffre les données avec AES-256-GCM.
8. Retourne l'en-tête suivi du texte chiffré et de son tag d'authentification.

Les paramètres sont enregistrés dans l'en-tête afin que le programme puisse les retrouver lors du déchiffrement.




### 6.5. `dechiffrer()`

Cette fonction réalise l'opération inverse.

Elle vérifie d'abord que le contenu possède une taille minimale et une signature reconnue. Elle lit ensuite les paramètres Argon2id, les valide et récupère le sel, le nonce, l'en-tête et le texte chiffré.

Elle dérive la même clé à partir du mot de passe fourni, puis appelle AES-GCM pour déchiffrer les données.

Si le mot de passe est incorrect ou si les données authentifiées ont été modifiées, le déchiffrement échoue.




### 6.6. `rechiffrer()`

Cette fonction permet de changer le mot de passe utilisé pour protéger les données.

Elle :

1. Déchiffre les données avec l'ancien mot de passe.
2. Chiffre à nouveau ces données avec le nouveau mot de passe.
3. Retourne le nouveau contenu chiffré.

Le résultat utilise un nouvel en-tête, un nouveau sel et un nouveau nonce.




### 6.7. Signification de `nom`, `donnees` et `blob`

- `nom` : nom du fichier associé aux données, utilisé dans les données associées authentifiées.
- `donnees` : données originales en clair à chiffrer, représentées par des octets.
- `blob` : ensemble binaire contenant l'en-tête et le contenu chiffré.

Les fonctions de ce projet manipulent des données en mémoire. Elles n'ouvrent pas automatiquement un fichier du système de fichiers et ne créent pas elles-mêmes un fichier chiffré sur le disque.




## 7. Format du fichier chiffré CFR1

Le format utilisé commence par la signature `CFR1`, qui permet de reconnaître sa version.

L'en-tête a une taille fixe de 44 octets.

| Élément              | Taille          | Description                                          |
|----------------------|-----------------|------------------------------------------------------|
| Signature `CFR1`     | 4 octets        | Identifie le format.                                 |
| Paramètre `T`        | 4 octets        | Nombre de passes Argon2id.                           |
| Paramètre `M`        | 4 octets        | Mémoire Argon2id en Kio.                             | 
| Paramètre `P`        | 4 octets        | Parallélisme Argon2id.                               |
| Sel                  | 16 octets       | Sert à dériver la clé à partir du mot de passe.      |
| Nonce                | 12 octets       | Valeur utilisée par AES-GCM.                         |
| Texte chiffré et tag | Taille variable | Données chiffrées suivies du tag d'authentification. |

Les paramètres `T`, `M` et `P` sont encodés sous forme de trois entiers de 32 bits en ordre big-endian.

La taille de l'en-tête est donc :

`4 + 12 + 16 + 12 = 44 octets`

AES-GCM ajoute un tag d'authentification de 16 octets au texte chiffré. La taille minimale du contenu complet est donc de 60 octets.




## 8. Données associées authentifiées (AAD)

Le programme construit les données associées authentifiées à partir de :

- l'en-tête complet de 44 octets ;
- la représentation UTF-8 du nom du fichier.

Ces données sont fournies à AES-GCM lors du chiffrement et doivent être identiques lors du déchiffrement.

L'en-tête et le nom ne sont pas chiffrés en tant que tels, mais leur intégrité est protégée par l'authentification AES-GCM.

Ainsi, modifier le nom du fichier associé ou modifier l'en-tête entraîne un échec de l'authentification lors du déchiffrement.




## 9. Exécuter les tests

Vérifier que l'environnement virtuel est activé et que le terminal se trouve dans le dossier du projet.

Lancer ensuite :

```bash
python -m pytest -v
```

L'option `-v` affiche le nom de chaque test et son résultat.

Les tests vérifient notamment :

- le chiffrement suivi du déchiffrement ; ici fonction test_chiffrement_dechiffrement()=fonction test_Aller-retour()
    dans notre fichier test_coffre.py
- la différence entre deux résultats de chiffrement du même contenu ;
- le rejet d'un mot de passe incorrect ;
- la détection de modifications du contenu chiffré ;
- le rejet d'un nom de fichier différent ;
- les fonctions de rechiffrement ;
- les paramètres Argon2id, selon les tests conservés dans `test_coffre.py`.

Un test réussi affiche `PASSED`.



## 10. Questions de réflexion

### 10.1. Pourquoi utiliser un sel ?

Le sel est une valeur aléatoire utilisée lors de la dérivation de la clé avec Argon2id.

Il permet d'obtenir des clés différentes même lorsque plusieurs utilisateurs choisissent le même mot de passe.

Il rend également moins efficaces les tables précalculées utilisées pour attaquer des mots de passe.

Le sel n'est pas secret : il peut être enregistré dans l'en-tête du fichier chiffré.



### 10.2. Pourquoi utiliser un nonce ?

Le nonce est une valeur utilisée par AES-GCM pour une opération de chiffrement.

Il doit être unique pour chaque chiffrement réalisé avec une même clé. Sa réutilisation avec la même clé peut compromettre gravement la sécurité du chiffrement et de l'authentification.

Dans ce projet, un nonce aléatoire de 12 octets est généré lors de chaque chiffrement.



### 10.3. Pourquoi inclure le nom du fichier dans l'AAD ?

Le nom du fichier est inclus dans les données associées authentifiées pour lier le contenu chiffré au nom attendu.

Si le nom utilisé au déchiffrement est différent de celui utilisé au chiffrement, la vérification d'authenticité échoue.

Cela permet de détecter un renommage non autorisé dans le contexte de cette application.



### 10.4. Pourquoi authentifier l'en-tête ?

L'en-tête contient notamment la signature, les paramètres Argon2id, le sel et le nonce.

Si l'en-tête était modifié sans être authentifié, le programme pourrait interpréter des informations altérées.

En l'incluant dans l'AAD, AES-GCM protège son intégrité et son authenticité.



### 10.5. Pourquoi éviter des messages d'erreur trop précis lors du déchiffrement ?

Des messages trop détaillés peuvent aider un attaquant à distinguer différentes causes d'échec et à adapter ses tentatives.

Une application destinée à être utilisée en production devrait présenter un message d'erreur générique à l'utilisateur, par exemple :

« Impossible de déchiffrer les données : mot de passe incorrect ou fichier altéré. »

Les détails techniques peuvent être consignés dans des journaux protégés, sans révéler d'informations sensibles à l'utilisateur.




## 11. Limites du projet et précautions

Ce projet constitue un exercice pédagogique de cryptographie.

- Les fonctions manipulent des octets et ne fournissent pas encore une interface de gestion de fichiers.
- Le mot de passe ne doit pas être enregistré en clair dans le code.
- Les clés dérivées ne doivent pas être affichées ou enregistrées inutilement.
- Le sel peut être public, mais le mot de passe doit rester secret.
- Un nonce ne doit jamais être réutilisé avec la même clé AES-GCM.
- Les paramètres Argon2id doivent être validés avant leur utilisation.
- Le temps de dérivation dépend du matériel et des paramètres choisis.




## 12. Conclusion

Ce TP met en pratique la combinaison de plusieurs mécanismes cryptographiques : Argon2id pour dériver une clé à partir d'un mot
 de passe, HKDF-SHA256 pour produire une sous-clé, et AES-256-GCM pour chiffrer et authentifier les données.

Le format versionné `CFR1` permet de conserver les paramètres nécessaires au déchiffrement et d'authentifier l'en-tête ainsi que
 le nom du fichier associé.

Les tests automatisés permettent de vérifier les principales propriétés fonctionnelles et de sécurité du mini-coffre-fort.
