import os
import struct

from argon2.low_level import hash_secret_raw, Type
from cryptography.hazmat.primitives.kdf.hkdf import HKDF
from cryptography.hazmat.primitives import hashes
from cryptography.hazmat.primitives.ciphers.aead import AESGCM

# Paramètres par défaut d'Argon2id
T, M, P = 30, 64 * 1024, 4

# Identifiant du format de fichier
MAGIC = b"CFR1"

# Fonction permettant de controler les parametres Argon2id
def valider_parametres_argon2(temps: int, memoire: int, parallelisme: int) -> None:
    """Vérifie que les paramètres Argon2id restent dans des limites autorisées."""
    if not 1 <= temps <= 30:
        raise ValueError("Paramètre de temps Argon2id non autorisé.")
    if not 8 * 1024 <= memoire <= 256 * 1024:
        raise ValueError("Paramètre de mémoire Argon2id non autorisé.")
    if not 1 <= parallelisme <= 8:
        raise ValueError("Paramètre de parallélisme Argon2id non autorisé.")
    if memoire < 8 * parallelisme:
        raise ValueError("Combinaison de paramètres Argon2id invalide.")
# Taille des éléments de l'en-tête
TAILLE_SEL = 16
TAILLE_NONCE = 12
TAILLE_ENTETE = 44

def cle_maitresse(
    mot_de_passe: str,
    sel: bytes,
    temps: int = T,
    memoire: int = M,
    parallelisme: int = P
) -> bytes:
    """Dérive une clé maîtresse de 32 octets avec Argon2id."""
    return hash_secret_raw(
        secret=mot_de_passe.encode("utf-8"),
        salt=sel,
        time_cost=temps,
        memory_cost=memoire,
        parallelism=parallelisme,
        hash_len=32,
        type=Type.ID
    )

def sous_cle(maitresse: bytes, usage: bytes) -> bytes:
    """Dérive une sous-clé de 32 octets avec HKDF-SHA256."""
    deriveur = HKDF(
        algorithm=hashes.SHA256(),
        length=32,
        salt=None,
        info=b"coffre-v1|" + usage
    )
    return deriveur.derive(maitresse)

def chiffrer(mot_de_passe: str, nom: str, donnees: bytes) -> bytes:
    """Chiffre des données avec AES-256-GCM et construit un fichier CFR1."""
    # 1. Générer un sel et un nonce aléatoires
    sel = os.urandom(TAILLE_SEL)
    nonce = os.urandom(TAILLE_NONCE)

    # 2. Construire la partie de l'en-tête contenant les paramètres
    parametres = struct.pack(">III", T, M, P)

    # 3. Construire l'en-tête complet
    entete = MAGIC + parametres + sel + nonce

    # 4. Dériver la clé maîtresse puis la sous-clé de chiffrement
    maitresse = cle_maitresse(mot_de_passe, sel, T, M, P)
    cle = sous_cle(maitresse, b"chiffrement")

    # 5. Préparer les données associées (AAD)
    aad = entete + nom.encode("utf-8")

    # 6. Chiffrer et authentifier les données
    moteur = AESGCM(cle)
    chiffre = moteur.encrypt(nonce, donnees, aad)

# 7. Retourner l'en-tête suivi des données chiffrées
    return entete + chiffre

def dechiffrer(mot_de_passe: str, nom: str, blob: bytes) -> bytes:
    """Déchiffre un fichier CFR1 et vérifie son authenticité."""

    # 1. Vérifier que le fichier est suffisamment long
    if len(blob) < TAILLE_ENTETE + 16:
        raise ValueError("Fichier chiffré trop court.")

    # 2. Vérifier la signature du format
    if blob[:4] != MAGIC:
        raise ValueError("Format de fichier inconnu.")

    # 3. Extraire et vérifier les paramètres Argon2id
    temps, memoire, parallelisme = struct.unpack(">III", blob[4:16])
    valider_parametres_argon2(temps, memoire, parallelisme)

    # 4. Extraire le sel et le nonce
    sel = blob[16:32]
    nonce = blob[32:44]

    # 5. Extraire les données chiffrées et le tag
    chiffre = blob[TAILLE_ENTETE:]

    # 6. Reconstituer l'en-tête
    entete = blob[:TAILLE_ENTETE]

    # 7. Dériver les clés
    maitresse = cle_maitresse(
        mot_de_passe,
        sel,
        temps,
        memoire,
        parallelisme
    )

    cle = sous_cle(maitresse, b"chiffrement")

    # 8. Reconstituer les données associées
    aad = entete + nom.encode("utf-8")

    # 9. Déchiffrer et vérifier l'authenticité
    moteur = AESGCM(cle)
    donnees = moteur.decrypt(nonce, chiffre, aad)

    return donnees

def rechiffrer(
    ancien_mot_de_passe: str,
    nouveau_mot_de_passe: str,
    nom: str,
    blob: bytes
) -> bytes:
    """Change le mot de passe d'un fichier CFR1."""

    # 1. Déchiffrer avec l'ancien mot de passe
    donnees = dechiffrer(
        ancien_mot_de_passe,
        nom,
        blob
    )

    # 2. Chiffrer à nouveau avec le nouveau mot de passe
    nouveau_blob = chiffrer(
        nouveau_mot_de_passe,
        nom,
        donnees
    )

    # 3. Retourner le nouveau fichier chiffré
    return nouveau_blob
