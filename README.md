# SoundCloud Robot Downloader

Automatiza con **Robot Framework + Selenium** la descarga de temas desde **SoundCloud** a partir de una **playlist**.  
El robot abre la playlist, entra en la pista *N*, intenta descargar si hay botón **Download** y, si la pista redirige a un **gate de Hypeddit**, abre ese gate en una pestaña nueva y ejecuta el flujo de Hypeddit (abrir, paso de Instagram, “Next”, y descarga final).

> Diseñado para **Windows + Microsoft Edge**, reutilizando tu **perfil real** (cookies/sesión) para evitar logins repetidos.

---

## ✨ Características

- Usa Edge con tu **perfil por defecto** (historial, cookies, sesión iniciada).
- Abre una **playlist** de SoundCloud y entra a la **pista N** (1-based).
- Si existe **Download** nativo en SoundCloud → lo pulsa.
- Si la pista enlaza a **Hypeddit** → abre en nueva pestaña y ejecuta el **flujo de Hypeddit**.
- Guarda descargas y metadatos (título, artista, portada) en carpetas bajo `results/` por defecto.

---

## 🧰 Requisitos

- **Windows** con **Microsoft Edge** instalado.
- **Python 3.10+**
- **Robot Framework** y **SeleniumLibrary** (instalación mediante `requirements.txt`).

---

## ⚙️ Preparación del entorno

1) Clonar el repo:

   ```bash
   git clone https://github.com/phernandez024/soundcloud-robot.git
   cd soundcloud-robot

2) Crear y activar el entorno virtual (venv):

   ```bash
   python -m venv .venv
   . .\.venv\Scripts\Activate.ps1


3) Instalar dependencias:

   ```bash
   pip install -r requirements.txt

## 🔐 Primer uso: iniciar sesión en Edge

**Antes de ejecutar por primera vez:**

- Abre **Microsoft Edge** manualmente con tu usuario y **loguea en SoundCloud** (y en Hypeddit si aplica).  
  El robot reutiliza tu **perfil real** y aprovechará esa sesión iniciada.

> También puedes ejecutar una suite de “setup/login” si el proyecto la incluye para abrir Edge con tu perfil y facilitar el primer login.

---

## ▶️ Ejecución

El proyecto incluye suites y resources de Robot Framework. Los nombres pueden variar, pero el flujo típico es:

### 1) Descarga desde una playlist de SoundCloud

```powershell
robot -d results test.robot
```
Variables útiles (puedes sobreescribirlas por CLI)

PLAYLIST_URL → URL de la playlist

TRACK_NUM → nº de pista (1-based)

DOWNLOAD_DIR → carpeta donde se guardan las descargas

(según tu suite, puede haber otras como META_DIR, COVERS_DIR, etc.)
