#!/bin/sh
python3 -m ocrmypdf -l deu --force-ocr --deskew --rotate-pages --output-type pdf --optimize 0 "$1" "$2"