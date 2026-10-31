
import pytest

from coffre import valider_parametres_argon2
from cryptography.exceptions import InvalidTag
from coffre import chiffrer, dechiffrer, rechiffrer

# fonction test_Aller-retour() = fonction test_chiffrement_dechiffrement()

def test_chiffrement_dechiffrement():
    """Vérifie que le message original est retrouvé."""
    message = b"Mon premier secret"

    blob = chiffrer("MotDePasseTest!", "message.txt", message)
    resultat = dechiffrer("MotDePasseTest!", "message.txt", blob)

    assert resultat == message


def test_deux_chiffrements_differents():
    """Vérifie que deux chiffrements du même message diffèrent."""
    message = b"Mon premier secret"

    blob1 = chiffrer("MotDePasseTest!", "message.txt", message)
    blob2 = chiffrer("MotDePasseTest!", "message.txt", message)

    assert blob1 != blob2


def test_mauvais_mot_de_passe():
    """Vérifie qu'un mauvais mot de passe est détecté."""
    blob = chiffrer(
        "BonMotDePasse!",
        "message.txt",
        b"Secret"
    )

    with pytest.raises(InvalidTag):
        dechiffrer(
            "MauvaisMotDePasse!",
            "message.txt",
            blob
        )


def test_modification_donnees_chiffrees():
    """Vérifie qu'une modification du fichier est détectée."""
    blob = bytearray(
        chiffrer(
            "MotDePasseTest!",
            "message.txt",
            b"Secret"
        )
    )

    blob[-1] ^= 1

    with pytest.raises(InvalidTag):
        dechiffrer(
            "MotDePasseTest!",
            "message.txt",
            bytes(blob)
        )


def test_changement_nom_fichier():
    """Vérifie que le nom du fichier est authentifié."""
    blob = chiffrer(
        "MotDePasseTest!",
        "message.txt",
        b"Secret"
    )

    with pytest.raises(InvalidTag):
        dechiffrer(
            "MotDePasseTest!",
            "autre.txt",
            blob
        )



def test_rechiffrement():
    """Vérifie que le contenu reste intact après le changement de mot de passe."""

    message = b"Document confidentiel"

    ancien_blob = chiffrer(
        "AncienSecret123!",
        "document.txt",
        message
    )

    nouveau_blob = rechiffrer(
        "AncienSecret123!",
        "NouveauSecret456!",
        "document.txt",
        ancien_blob
    )

    resultat = dechiffrer(
        "NouveauSecret456!",
        "document.txt",
        nouveau_blob
    )

    assert resultat == message
    assert nouveau_blob != ancien_blob




def test_parametres_argon2_excessifs():
    """Vérifie qu'une mémoire excessive est refusée."""
    with pytest.raises(ValueError):
        valider_parametres_argon2(3, 10**9, 4)
