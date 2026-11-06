#!/usr/bin/env bash
# Systemabhaengigkeiten fuer ocr_pdf.py; Python-Pakete separat installieren.
set -euo pipefail

admin=()
if (( EUID != 0 )); then
    command -v sudo >/dev/null || { echo "Bitte als root starten (sudo fehlt)." >&2; exit 1; }
    admin=(sudo)
fi

if command -v apt-get >/dev/null; then
    "${admin[@]}" apt-get update
    "${admin[@]}" apt-get install -y tesseract-ocr tesseract-ocr-deu tesseract-ocr-osd ghostscript
elif command -v dnf >/dev/null; then
    "${admin[@]}" dnf install -y tesseract tesseract-langpack-deu tesseract-osd ghostscript
elif command -v pacman >/dev/null; then
    # Vollstaendiges Upgrade statt eines unter Arch nicht unterstuetzten Teilupgrades.
    "${admin[@]}" pacman -Syu --needed tesseract tesseract-data-deu tesseract-data-osd ghostscript
else
    echo "Unterstuetzt: Debian/Ubuntu, Fedora/RHEL mit passenden Paketquellen, Arch Linux." >&2
    echo "Bitte Tesseract, Deutsch (deu), Ausrichtung (osd) und Ghostscript manuell installieren." >&2
    exit 1
fi

# Keine globale Sprachpfadvariable setzen; Systemstandard verwenden.
unset TESSDATA_PREFIX
tesseract --version
gs --version
langs="$(tesseract --list-langs 2>&1)"
printf '%s\n' "$langs"
grep -Eq '^[[:space:]]*deu[[:space:]]*$' <<< "$langs" || { echo "Sprachpaket deu fehlt." >&2; exit 1; }
grep -Eq '^[[:space:]]*osd[[:space:]]*$' <<< "$langs" || { echo "Sprachpaket osd fehlt." >&2; exit 1; }
echo "Fertig. Falls TESSDATA_PREFIX zuvor selbst gesetzt wurde, muss es zum Systemordner passen."
echo "Python-Pakete separat installieren: python3 -m pip install -r requirements.txt (ggf. in einer virtuellen Umgebung)."
