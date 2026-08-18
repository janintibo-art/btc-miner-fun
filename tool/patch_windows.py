"""Renomme l'executable et la fenetre Windows generes par flutter create."""
import pathlib

cmake = pathlib.Path("windows/CMakeLists.txt")
if cmake.exists():
    text = cmake.read_text(encoding="utf-8")
    text = text.replace('set(BINARY_NAME "btc_miner_fun")', 'set(BINARY_NAME "BTCMinerFun")')
    cmake.write_text(text, encoding="utf-8")
    print("Nom de l'executable : BTCMinerFun.exe")

main_cpp = pathlib.Path("windows/runner/main.cpp")
if main_cpp.exists():
    text = main_cpp.read_text(encoding="utf-8")
    text = text.replace('L"btc_miner_fun"', 'L"BTC Miner Fun"')
    main_cpp.write_text(text, encoding="utf-8")
    print("Titre de la fenetre : BTC Miner Fun")
