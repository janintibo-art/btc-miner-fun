"""Controle statique leger, sans SDK Dart.

Trois defauts se sont repetes au fil des versions, toujours pour la meme
raison : une modification de fichier appliquee par recherche de motif, dont le
point d'ancrage n'existait plus. Le code compilait dans ma tete, pas dans le
depot. Ce script attrape ces cas avant la compilation.

  1. une classe privee utilisee mais definie nulle part dans son fichier ;
  2. un import relatif dont le symbole principal n'apparait pas ;
  3. un import de bibliotheque standard devenu inutile.

Il ne remplace pas `flutter analyze`, il donne le meme verdict en une seconde.
"""
import pathlib
import re
import sys

RACINE = pathlib.Path("lib")

# Symbole principal attendu pour quelques modules, afin de reperer les imports
# devenus inutiles apres une refonte.
SYMBOLES = {
    "platform_profile": "PlatformProfile",
    "app_version": "kAppVersion",
    "lottery_sim": "runLotterySimulation",
    "avalanche": "runAvalancheTest",
    "coinbase_decoder": "decodeCoinbase",
    "screensaver_screen": "ScreensaverScreen",
    "wallet_screen": "WalletScreen",
    "benchmark_card": "BenchmarkCard",
    "job_inspector": "JobInspector",
    "sparkline": "Sparkline",
    "log_console": "LogConsole",
    "address_validator": "checkBitcoinAddress",
    "wallet_watch": "WalletBalance",
    "nonce_walker": "NonceStrategy",
    "hash_mode": "HashMode",
    "session": "MiningSession",
    "gpu_probe": "probeGpuDevices",
    "hardware_card": "HardwareCard",
}

STANDARD = {
    "dart:io": ["Platform.", "File(", "Directory(", "HttpClient", "Socket",
                "HttpHeaders", "HttpException", "SocketOption"],
    "dart:math": ["math.", "Random(", "Random.", "max(", "min(", "sqrt(", "pow("],
    "dart:typed_data": ["Uint8List", "Uint32List", "ByteData"],
    "dart:convert": ["jsonEncode", "jsonDecode", "utf8", "LineSplitter", "base64"],
    "dart:isolate": ["Isolate", "SendPort", "ReceivePort"],
    "dart:ffi": ["DynamicLibrary", "Pointer", "Int32", "Uint8"],
    "dart:async": ["Future", "Timer", "Stream", "Completer", "unawaited"],
}

problemes = []

for fichier in sorted(RACINE.rglob("*.dart")):
    source = fichier.read_text(encoding="utf-8")
    lignes = source.split("\n")
    corps = "\n".join(l for l in lignes if not l.lstrip().startswith("import "))
    sans_chaines = re.sub(r"'[^'\n]*'|\"[^\"\n]*\"", "''", corps)
    sans_chaines = re.sub(r"//.*", "", sans_chaines)

    # 1. Classes privees utilisees mais jamais definies.
    definies = set(re.findall(r"(?:class|enum|mixin)\s+(_\w+)", source))
    utilisees = set(re.findall(r"\b(_[A-Z]\w+)\s*\(", sans_chaines))
    utilisees |= set(re.findall(r"State<\w+>\s*=>\s*(_\w+)\(", sans_chaines))
    for nom in sorted(utilisees - definies):
        problemes.append(
            "{0} : la classe {1} est utilisee mais n'existe pas dans ce fichier"
            .format(fichier, nom))

    # 2. Imports relatifs dont le symbole principal est absent.
    for prefixe, cible in re.findall(r"import '((?:\.\./|\./)+)([^']+)\.dart'", source):
        chemin = (fichier.parent / prefixe / (cible + ".dart")).resolve()
        if not chemin.exists():
            problemes.append("{0} : import introuvable {1}{2}.dart".format(
                fichier, prefixe, cible))
            continue
        nom_module = cible.split("/")[-1]
        symbole = SYMBOLES.get(nom_module)
        if symbole:
            variantes = {symbole, symbole[0].lower() + symbole[1:]}
        if symbole and not any(v in corps for v in variantes):
            problemes.append(
                "{0} : import de {1}.dart inutilise ({2} absent)".format(
                    fichier, nom_module, symbole))

    # 3. Imports de bibliotheque standard devenus inutiles.
    for bibliotheque, marqueurs in STANDARD.items():
        if "import '{0}'".format(bibliotheque) in source or \
           "import '{0}' as ".format(bibliotheque) in source:
            if not any(marqueur in corps for marqueur in marqueurs):
                problemes.append(
                    "{0} : import de {1} inutilise".format(fichier, bibliotheque))

if problemes:
    print("Problemes detectes :\n")
    for probleme in problemes:
        print("  -", probleme)
    sys.exit(1)

print("Sources coherentes : aucune classe manquante, aucun import inutile.")
