@echo off
py -m ocrmypdf -l deu --force-ocr --deskew --rotate-pages --output-type pdf --optimize 0 "%~1" "%~2"