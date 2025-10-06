# SoundCloud Robot Downloader

Suite de Robot Framework para abrir una playlist de SoundCloud, abrir la pista N por:
- **click** (abrir página de la pista) o
- **hover** (en la propia playlist)

y descargar el archivo si existe la opción **Download**.

## Requisitos
- Python 3.10+
- Microsoft Edge + WebDriver compatible (vinculado por SeleniumManager en Selenium 4+)
- Robot Framework, SeleniumLibrary

```bash
python -m venv .venv
. .venv/Scripts/activate  # Windows
pip install -r requirements.txt
