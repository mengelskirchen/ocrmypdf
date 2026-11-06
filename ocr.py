"""PDF mit deutscher OCR verarbeiten.

Aufruf:
    python ocr_pdf.py input.pdf output.pdf

Python >= 3.10. Zusaetzlich erforderlich: Tesseract mit deutschem
Sprachpaket (deu), je nach OCRmyPDF-Version auch Ghostscript.
"""

import argparse
import importlib.util
from pathlib import Path
import subprocess
import sys


def main():
    parser = argparse.ArgumentParser(
        description="Deutsche OCR mit Entzerrung und automatischer Seitenausrichtung."
    )
    parser.add_argument("input", type=Path, help="Eingabe-PDF")
    parser.add_argument("output", type=Path, help="Neue Ausgabe-PDF")
    args = parser.parse_args()

    eingabe = args.input.expanduser().resolve()
    ausgabe = args.output.expanduser().resolve()

    if not eingabe.is_file():
        parser.error(f"Eingabedatei nicht gefunden: {eingabe}")
    if eingabe == ausgabe:
        parser.error("Eingabe und Ausgabe muessen unterschiedliche Dateien sein.")
    if ausgabe.exists():
        parser.error(f"Die Ausgabedatei existiert bereits: {ausgabe}")
    if not ausgabe.parent.is_dir():
        parser.error(f"Der Ausgabeordner existiert nicht: {ausgabe.parent}")
    if importlib.util.find_spec("ocrmypdf") is None:
        parser.error("OCRmyPDF fehlt. Bitte zuerst installieren: python -m pip install -r requirements.txt")

    # Dieselbe Python-Umgebung verwenden, keine Shell-Abhaengigkeit.
    # Dateipfade mit Leerzeichen funktionieren durch die Argumentliste.
    befehl = [
        sys.executable, "-m", "ocrmypdf",
        "-l", "deu",
        "--force-ocr",
        "--deskew",
        "--rotate-pages",
        "--output-type", "pdf",
        "--optimize", "0",
        str(eingabe), str(ausgabe),
    ]

    try:
        ergebnis = subprocess.run(befehl, check=False)
    except KeyboardInterrupt:
        print("\nAbgebrochen.", file=sys.stderr)
        return 130
    except OSError as exc:
        print(f"OCRmyPDF konnte nicht gestartet werden: {exc}", file=sys.stderr)
        return 1

    if ergebnis.returncode == 0:
        print(f"Fertig: {ausgabe}")
    return ergebnis.returncode


if __name__ == "__main__":
    sys.exit(main())
