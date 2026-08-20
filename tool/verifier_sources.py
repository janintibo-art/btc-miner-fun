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
    "gpu_miner": "runGpuSelfTest",
    "mining_algorithm": "MiningAlgorithm",
    "scrypt": "Scrypt",
    "coin_stats": "CoinStats",
    "coins": "Coin",
    "mining_ranking": "RankedCoin",
    "block_feed": "BlockFeed",
    "thermal_guard": "ThermalGuard",
    "session_export": "SessionExport",
    "my_chain": ["MyChain", "MyBlock", "ChainRules"],
    "my_chain_miner": "mineChainBatch",
    "chain_controller": "ChainController",
    "my_chain_screen": "MyChainScreen",
    "chain_network": "ChainNetwork",
    "celebration": "Celebration",
    "hash_roulette_screen": "HashRouletteScreen",
    "certificate_screen": "CertificateScreen",
    "miner_ranking": ["MinerScore", "rankMiners", "luckiestBlock"],
    "ranking_card": "RankingCard",
    "block_feed_card": "BlockFeedCard",
    "hardware_card": "HardwareCard",
}

STANDARD = {
    "dart:io": ["Platform.", "File(", "Directory(", "HttpClient", "Socket",
                "HttpHeaders", "HttpException", "SocketOption"],
    "dart:math": ["math.", "Random(", "Random.", "max(", "min(", "sqrt(",
                  "pow(", "ln10", "ln2", "exp(", " log(", "(log(", "pi"],
    "dart:typed_data": ["Uint8List", "Uint32List", "ByteData"],
    "dart:convert": ["jsonEncode", "jsonDecode", "utf8", "LineSplitter",
                     "base64", "JsonEncoder", "JsonDecoder", "json."],
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
        attendu = SYMBOLES.get(nom_module)
        # Un module peut exporter plusieurs types : il suffit qu'un seul soit
        # utilise pour que l'import se justifie.
        symbole = attendu[0] if isinstance(attendu, list) else attendu
        if isinstance(attendu, list):
            if any(nom in corps for nom in attendu):
                continue
            problemes.append(
                "{0} : import de {1}.dart inutilise ({2} absents)".format(
                    fichier, nom_module, ", ".join(attendu)))
            continue
        if symbole:
            # Un module peut etre importe pour son type comme pour sa
            # fonction, ou pour un type voisin du meme fichier : on accepte
            # les graphies proches plutot que le seul symbole principal.
            racine = symbole.rstrip('s')
            variantes = {symbole, symbole[0].lower() + symbole[1:],
                         symbole[0].upper() + symbole[1:], racine}
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

# 4. Membres du controleur appeles depuis l'interface mais jamais definis.
#    C'est le meme defaut que les classes manquantes, applique a l'etat
#    partage : une insertion ratee laisse un appel sans cible.
controleur = pathlib.Path("lib/state/miner_controller.dart")
if controleur.exists():
    source_controleur = controleur.read_text(encoding="utf-8")
    # N'importe quelle declaration de membre : type quelconque, generiques et
    # point d'interrogation compris.
    definis = set(re.findall(
        r"^\s{2}(?:final\s+|late\s+|static\s+)*[\w<>,\s?(){}:]+?\s+(\w+)\s*[=;]",
        source_controleur, re.M))
    definis |= set(re.findall(r"get\s+(\w+)", source_controleur))
    definis |= set(re.findall(r"(\w+)\s*\(", source_controleur))

    appeles = set()
    for fichier in sorted(RACINE.rglob("*.dart")):
        if "miner_controller" in str(fichier):
            continue
        texte = fichier.read_text(encoding="utf-8")
        appeles |= set(re.findall(r"\bm\.(\w+)", texte))

    manquants = sorted(a for a in appeles - definis if not a.startswith("_"))
    for nom in manquants:
        problemes.append(
            "lib/state/miner_controller.dart : membre '{0}' utilise par "
            "l'interface mais introuvable".format(nom))

# 5. Navigation : ecrans, titres, barre du bas et rail lateral doivent
#    compter le meme nombre d'entrees.
principal = pathlib.Path("lib/main.dart")
if principal.exists():
    texte = principal.read_text(encoding="utf-8")
    try:
        bloc_titres = texte[texte.index("static const _titles"):]
        bloc_titres = bloc_titres[:bloc_titres.index("];")]
        titres = len(re.findall(r"'\w+'", bloc_titres))

        bloc_items = texte[texte.index("static const _items"):]
        bloc_items = bloc_items[:bloc_items.index("@override")]
        rail = bloc_items.count("label:")

        barre = texte.count("NavigationDestination(")
        ecrans = len(re.findall(r"\n\s{14}\w+Screen\(\),", texte))

        if not (titres == rail == barre == ecrans):
            problemes.append(
                "lib/main.dart : navigation incoherente - {0} titres, {1} "
                "entrees de rail, {2} entrees de barre, {3} ecrans".format(
                    titres, rail, barre, ecrans))
    except ValueError:
        problemes.append("lib/main.dart : structure de navigation illisible")

if problemes:
    print("Problemes detectes :\n")
    for probleme in problemes:
        print("  -", probleme)
    sys.exit(1)

print("Sources coherentes : aucune classe manquante, aucun import inutile.")
