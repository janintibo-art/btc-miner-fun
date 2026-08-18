"""Ajoute la permission INTERNET au manifeste Android et renomme l'application.

Flutter ne met la permission INTERNET que dans les manifestes de debug :
sans ce patch, l'APK release ne peut pas se connecter a un pool.
"""
import pathlib
import sys

manifest = pathlib.Path("android/app/src/main/AndroidManifest.xml")
if not manifest.exists():
    sys.exit("Manifeste introuvable : lance d'abord flutter create.")

text = manifest.read_text(encoding="utf-8")

if "android.permission.INTERNET" not in text:
    text = text.replace(
        "<application",
        '<uses-permission android:name="android.permission.INTERNET"/>\n'
        '    <uses-permission android:name="android.permission.WAKE_LOCK"/>\n'
        "    <application",
        1,
    )

text = text.replace('android:label="btc_miner_fun"', 'android:label="BTC Miner Fun"')

manifest.write_text(text, encoding="utf-8")
print("Manifeste Android mis a jour.")
