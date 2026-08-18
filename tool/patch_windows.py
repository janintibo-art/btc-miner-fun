"""Adapte le projet Windows genere par `flutter create`.

Trois choses que Flutter laisse par defaut et qui trahissent un portage
telephone : le nom de l'executable, le titre de la fenetre, et surtout sa
taille d'ouverture, calquee sur une fenetre de demonstration.
"""
import pathlib
import re

# --- Nom de l'executable ---------------------------------------------------
cmake = pathlib.Path("windows/CMakeLists.txt")
if cmake.exists():
    text = cmake.read_text(encoding="utf-8")
    text = text.replace(
        'set(BINARY_NAME "btc_miner_fun")', 'set(BINARY_NAME "BTCMinerFun")'
    )
    cmake.write_text(text, encoding="utf-8")
    print("Nom de l'executable : BTCMinerFun.exe")

# --- Titre et geometrie de la fenetre --------------------------------------
main_cpp = pathlib.Path("windows/runner/main.cpp")
if main_cpp.exists():
    text = main_cpp.read_text(encoding="utf-8")
    text = text.replace('L"btc_miner_fun"', 'L"BTC Miner Fun"')

    # La fenetre s'ouvrait en 1280x720 dans le coin superieur gauche. On passe
    # a une taille ou la navigation laterale et les cartes respirent, et on
    # centre plutot que de coller au bord.
    text, n_size = re.subn(
        r"Win32Window::Size size\(\s*\d+\s*,\s*\d+\s*\);",
        "Win32Window::Size size(1360, 900);",
        text,
        count=1,
    )
    text, n_origin = re.subn(
        r"Win32Window::Point origin\(\s*\d+\s*,\s*\d+\s*\);",
        "Win32Window::Point origin(80, 40);",
        text,
        count=1,
    )
    main_cpp.write_text(text, encoding="utf-8")
    print(
        "Fenetre : titre applique, taille {0}, position {1}.".format(
            "1360x900" if n_size else "inchangee",
            "80,40" if n_origin else "inchangee",
        )
    )

# --- Identite de l'executable dans les proprietes Windows ------------------
resources = pathlib.Path("windows/runner/Runner.rc")
if resources.exists():
    text = resources.read_text(encoding="utf-8")
    text = text.replace('"com.funminer" "\\0"', '"BTC Miner Fun" "\\0"')
    text = text.replace(
        'VALUE "FileDescription", "btc_miner_fun" "\\0"',
        'VALUE "FileDescription", "Mineur Bitcoin pedagogique" "\\0"',
    )
    text = text.replace(
        'VALUE "ProductName", "btc_miner_fun" "\\0"',
        'VALUE "ProductName", "BTC Miner Fun" "\\0"',
    )
    resources.write_text(text, encoding="utf-8")
    print("Proprietes de l'executable mises a jour.")
