import yt_dlp
import sys
import os
import json
import subprocess
import time
from pathlib import Path
from datetime import datetime

# Configuración de rutas
COOKIES_PATH = r"C:\Users\USER\Downloads\soundcloud_cookies.txt"
DOWNLOAD_DIR = "./downloads"
TEMP_DIR = "./temp"
ROBOT_SCRIPT = "check_external_links.robot"

# Archivos temporales
URLS_FOR_ROBOT = os.path.join(TEMP_DIR, "urls_for_robot.json")
EXTERNAL_LINKS = os.path.join(TEMP_DIR, "external_links.json")
PROGRESS_FILE = os.path.join(TEMP_DIR, "progress.json")

# Configuración de rate limiting
DELAY_BETWEEN_CHECKS = 2  # segundos entre verificaciones
DELAY_BETWEEN_DOWNLOADS = 3  # segundos entre descargas
RATE_LIMIT_WAIT = 600  # 10 minutos en segundos
MAX_RETRIES = 3
BATCH_SIZE = 30  # Procesar en lotes para dar descansos


def setup_directories():
    """Crea los directorios necesarios"""
    os.makedirs(DOWNLOAD_DIR, exist_ok=True)
    os.makedirs(TEMP_DIR, exist_ok=True)


def check_cookies_exist():
    """Verifica que existe el archivo de cookies"""
    if not os.path.exists(COOKIES_PATH):
        print(f"✗ Error: No se encuentra el archivo de cookies en: {COOKIES_PATH}")
        print("\nAsegúrate de:")
        print("  1. Tener sesión iniciada en SoundCloud")
        print("  2. Exportar las cookies al archivo indicado")
        sys.exit(1)


def load_progress():
    """Carga el progreso guardado si existe"""
    if os.path.exists(PROGRESS_FILE):
        with open(PROGRESS_FILE, 'r', encoding='utf-8') as f:
            return json.load(f)
    return {
        'tracks_with_download': [],
        'tracks_for_robot': [],
        'last_checked_index': 0,
        'last_downloaded_index': 0,
        'completed': False
    }


def save_progress(progress):
    """Guarda el progreso actual"""
    with open(PROGRESS_FILE, 'w', encoding='utf-8') as f:
        json.dump(progress, f, indent=2, ensure_ascii=False)


def wait_for_rate_limit(wait_time=RATE_LIMIT_WAIT):
    """Espera cuando se alcanza el rate limit"""
    print(f"\n⏳ Rate limit alcanzado. Esperando {wait_time//60} minutos...")
    for remaining in range(wait_time, 0, -30):
        mins, secs = divmod(remaining, 60)
        print(f"   Tiempo restante: {mins:02d}:{secs:02d}", end='\r')
        time.sleep(30)
    print("\n✓ Continuando...")


def get_playlist_info(playlist_url):
    """Extrae información básica de la playlist sin descargar"""
    print(f"\n📋 Analizando playlist: {playlist_url}")
    
    ydl_opts = {
        'cookiefile': COOKIES_PATH,
        'quiet': True,
        'no_warnings': True,
        'extract_flat': 'in_playlist',
        'extractor_retries': MAX_RETRIES,
        'retry_sleep': 5,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(playlist_url, download=False)
            entries = info.get('entries', [])
            
            print(f"✓ Playlist encontrada: {info.get('title', 'Sin título')}")
            print(f"✓ Total de canciones: {len(entries)}")
            
            return entries
    except Exception as e:
        print(f"✗ Error al analizar playlist: {str(e)}")
        sys.exit(1)


def check_download_format(url, track_num, retry_count=0):
    """
    Verifica si una URL tiene el formato 'download' disponible
    Retorna: (tiene_download, info_dict, error)
    """
    ydl_opts = {
        'cookiefile': COOKIES_PATH,
        'quiet': True,
        'no_warnings': True,
        'extractor_retries': 0,  # Manejamos los reintentos manualmente
        'sleep_requests': 1,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            info = ydl.extract_info(url, download=False)
            formats = info.get('formats', [])
            has_download = any(f.get('format_id') == 'download' for f in formats)
            return has_download, info, None
            
    except yt_dlp.utils.DownloadError as e:
        error_str = str(e)
        if '429' in error_str and retry_count < MAX_RETRIES:
            print(f"  ⚠️  Rate limit - Reintento {retry_count + 1}/{MAX_RETRIES}")
            wait_for_rate_limit()
            return check_download_format(url, track_num, retry_count + 1)
        return False, None, error_str
    except Exception as e:
        return False, None, str(e)


def download_with_metadata(url, track_num, retry_count=0):
    """Descarga una canción con todos los metadatos y portada"""
    print(f"\n⬇️  [{track_num}] Descargando con archivo original...")
    
    # Primero obtenemos info para saber el formato
    try:
        with yt_dlp.YoutubeDL({'cookiefile': COOKIES_PATH, 'quiet': True}) as ydl:
            info = ydl.extract_info(url, download=False)
            formats = info.get('formats', [])
            download_format = next((f for f in formats if f.get('format_id') == 'download'), None)
            
            # Verificar si el formato soporta thumbnail embedding
            ext = download_format.get('ext', '').lower() if download_format else ''
            supports_thumb = ext in ['mp3', 'mkv', 'mka', 'ogg', 'opus', 'flac', 'm4a', 'mp4', 'm4v', 'mov']
            
            if not supports_thumb:
                print(f"  ℹ️  Formato {ext.upper()} no soporta thumbnail embebido")
                print(f"  ℹ️  Se guardará la portada como archivo separado")
    except Exception as e:
        print(f"  ⚠️  No se pudo verificar formato: {e}")
        supports_thumb = False
    
    # Configurar postprocesadores según el formato
    postprocessors = [{
        'key': 'FFmpegMetadata',
        'add_metadata': True,
    }]
    
    # Solo añadir EmbedThumbnail si el formato lo soporta
    if supports_thumb:
        postprocessors.append({
            'key': 'EmbedThumbnail',
            'already_have_thumbnail': False,
        })
    
    ydl_opts = {
        'cookiefile': COOKIES_PATH,
        'format': 'download/bestaudio/best',
        'outtmpl': os.path.join(DOWNLOAD_DIR, f'{track_num:03d} - %(uploader,artist|Unknown Artist)s - %(title)s.%(ext)s'),
        'writethumbnail': True,
        'addmetadata': True,
        'postprocessors': postprocessors,
        'quiet': False,
        'no_warnings': False,
        'extractor_retries': 0,
        'sleep_requests': 2,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
            print(f"  ✓ Track #{track_num} descargado exitosamente")
            return True
    except yt_dlp.utils.DownloadError as e:
        error_str = str(e)
        if '429' in error_str and retry_count < MAX_RETRIES:
            print(f"  ⚠️  Rate limit - Reintento {retry_count + 1}/{MAX_RETRIES}")
            wait_for_rate_limit()
            return download_with_metadata(url, track_num, retry_count + 1)
        print(f"  ✗ Error: {error_str}")
        return False
    except Exception as e:
        print(f"  ✗ Error al descargar track #{track_num}: {str(e)}")
        return False


def download_best_audio(url, track_num, retry_count=0):
    """Descarga la mejor calidad de audio disponible"""
    print(f"\n⬇️  [{track_num}] Descargando mejor calidad disponible...")
    
    # Determinar si el formato soportará thumbnail
    try:
        with yt_dlp.YoutubeDL({'cookiefile': COOKIES_PATH, 'quiet': True, 'format': 'bestaudio/best'}) as ydl:
            info = ydl.extract_info(url, download=False)
            # Predecir la extensión del mejor formato
            requested_formats = info.get('requested_formats', [info])
            ext = requested_formats[0].get('ext', '').lower()
            supports_thumb = ext in ['mp3', 'mkv', 'mka', 'ogg', 'opus', 'flac', 'm4a', 'mp4', 'm4v', 'mov']
            
            if not supports_thumb and ext:
                print(f"  ℹ️  Formato {ext.upper()} no soporta thumbnail embebido")
    except Exception as e:
        print(f"  ⚠️  No se pudo verificar formato: {e}")
        supports_thumb = True  # Por defecto intentar, ya que bestaudio suele ser m4a/mp3
    
    # Configurar postprocesadores
    postprocessors = [{
        'key': 'FFmpegMetadata',
        'add_metadata': True,
    }]
    
    if supports_thumb:
        postprocessors.append({
            'key': 'EmbedThumbnail',
            'already_have_thumbnail': False,
        })
    
    ydl_opts = {
        'cookiefile': COOKIES_PATH,
        'format': 'bestaudio/best',
        'outtmpl': os.path.join(DOWNLOAD_DIR, '%(playlist_index)03d - %(artist)s - %(title)s.%(ext)s'),
        'writethumbnail': True,
        'addmetadata': True,
        'postprocessors': postprocessors,
        'quiet': False,
        'no_warnings': False,
        'extractor_retries': 0,
        'sleep_requests': 2,
    }
    
    try:
        with yt_dlp.YoutubeDL(ydl_opts) as ydl:
            ydl.download([url])
            print(f"  ✓ Track #{track_num} descargado exitosamente")
            return True
    except yt_dlp.utils.DownloadError as e:
        error_str = str(e)
        if '429' in error_str and retry_count < MAX_RETRIES:
            print(f"  ⚠️  Rate limit - Reintento {retry_count + 1}/{MAX_RETRIES}")
            wait_for_rate_limit()
            return download_best_audio(url, track_num, retry_count + 1)
        print(f"  ✗ Error: {error_str}")
        return False
    except Exception as e:
        print(f"  ✗ Error: {str(e)}")
        return False


def process_playlist(playlist_url, resume=False):
    """Procesa toda la playlist con el flujo inteligente"""
    
    print("="*70)
    print("🎵 SOUNDCLOUD PLAYLIST DOWNLOADER (con manejo de Rate Limit)")
    print("="*70)
    
    # Cargar progreso si se está reanudando
    progress = load_progress() if resume else {
        'tracks_with_download': [],
        'tracks_for_robot': [],
        'last_checked_index': 0,
        'last_downloaded_index': 0,
        'completed': False
    }
    
    if resume and progress['last_checked_index'] > 0:
        print(f"\n♻️  Reanudando desde track #{progress['last_checked_index'] + 1}")
    
    # Fase 1: Análisis inicial
    entries = get_playlist_info(playlist_url)
    total_tracks = len(entries)
    
    print("\n" + "="*70)
    print("📊 FASE 1: Verificando disponibilidad de 'Download File'")
    print("="*70)
    print(f"⚠️  Se añadirá una pausa de {DELAY_BETWEEN_CHECKS}s entre verificaciones")
    
    start_idx = progress['last_checked_index']
    
    for idx in range(start_idx, total_tracks):
        entry = entries[idx]
        track_num = idx + 1
        url = entry.get('url') or entry.get('webpage_url')
        title = entry.get('title', 'Sin título')
        
        print(f"\n[{track_num}/{total_tracks}] {title}")
        print(f"  URL: {url}")
        
        has_download, info, error = check_download_format(url, track_num)
        
        if error:
            if '429' in error:
                print(f"  ⚠️  Rate limit persistente - guardando progreso")
                progress['last_checked_index'] = idx
                save_progress(progress)
                print(f"\n⏸️  Progreso guardado. Ejecuta con --resume para continuar")
                return False
            else:
                print(f"  ⚠️  Error: {error}")
        
        if has_download:
            print(f"  ✓ Tiene 'Download File' disponible")
            progress['tracks_with_download'].append({
                'num': track_num,
                'url': url,
                'title': title
            })
        else:
            print(f"  ℹ️  No tiene 'Download File' - revisar con Robot")
            progress['tracks_for_robot'].append({
                'num': track_num,
                'url': url,
                'title': title
            })
        
        # Guardar progreso cada 10 tracks
        if track_num % 10 == 0:
            progress['last_checked_index'] = idx
            save_progress(progress)
            print(f"  💾 Progreso guardado")
        
        # Pausa entre verificaciones
        if idx < total_tracks - 1:
            time.sleep(DELAY_BETWEEN_CHECKS)
        
        # Descanso cada BATCH_SIZE tracks
        if track_num % BATCH_SIZE == 0 and track_num < total_tracks:
            print(f"\n☕ Descanso de 30 segundos (procesados {track_num}/{total_tracks})...")
            time.sleep(30)
    
    progress['last_checked_index'] = total_tracks
    save_progress(progress)
    
    # Fase 2: Descargar archivos originales
    tracks_with_download = progress['tracks_with_download']
    
    if tracks_with_download:
        print("\n" + "="*70)
        print(f"⬇️  FASE 2: Descargando {len(tracks_with_download)} tracks con archivo original")
        print("="*70)
        print(f"⚠️  Pausa de {DELAY_BETWEEN_DOWNLOADS}s entre descargas")
        
        start_dl = progress['last_downloaded_index']
        
        for idx in range(start_dl, len(tracks_with_download)):
            track = tracks_with_download[idx]
            success = download_with_metadata(track['url'], track['num'])
            
            if not success:
                progress['last_downloaded_index'] = idx
                save_progress(progress)
                print(f"\n⏸️  Error en descarga. Progreso guardado.")
                return False
            
            progress['last_downloaded_index'] = idx + 1
            
            if idx < len(tracks_with_download) - 1:
                time.sleep(DELAY_BETWEEN_DOWNLOADS)
        
        save_progress(progress)
    
    # Fase 3: Robot Framework
    tracks_for_robot = progress['tracks_for_robot']
    
    if tracks_for_robot:
        print("\n" + "="*70)
        print(f"🤖 FASE 3: Preparando {len(tracks_for_robot)} tracks para Robot Framework")
        print("="*70)
        
        with open(URLS_FOR_ROBOT, 'w', encoding='utf-8') as f:
            json.dump(tracks_for_robot, f, indent=2, ensure_ascii=False)
        
        print(f"✓ URLs guardadas en: {URLS_FOR_ROBOT}")
        print("\n🤖 Iniciando Robot Framework...")
        print("⚠️  Nota: Robot también respetará pausas para evitar rate limiting")
        
        try:
            result = subprocess.run(
                ['robot', 
                 '--variable', f'URLS_FILE:{URLS_FOR_ROBOT}',
                 '--variable', f'OUTPUT_FILE:{EXTERNAL_LINKS}',
                 '--variable', f'DELAY:5',  # Pausa entre tracks en Robot
                 'check_external_links.robot'],
                capture_output=True,
                text=True
            )
            
            if result.returncode == 0:
                print("✓ Robot Framework ejecutado exitosamente")
            else:
                print(f"⚠️  Robot Framework terminó con código: {result.returncode}")
                if result.stdout:
                    print("STDOUT:", result.stdout[-500:])  # Últimas 500 chars
                if result.stderr:
                    print("STDERR:", result.stderr[-500:])
        except FileNotFoundError:
            print("⚠️  Robot Framework no instalado")
            print("    Ejecuta manualmente: robot check_external_links.robot")
            return True
        except Exception as e:
            print(f"⚠️  Error al ejecutar Robot: {str(e)}")
            return True
        
        # Fase 4: Procesar resultados
        if os.path.exists(EXTERNAL_LINKS):
            print("\n" + "="*70)
            print("📥 FASE 4: Procesando resultados de Robot Framework")
            print("="*70)
            
            with open(EXTERNAL_LINKS, 'r', encoding='utf-8') as f:
                external_data = json.load(f)
            
            tracks_direct_dl = []
            
            for track in external_data:
                track_num = track['num']
                url = track['url']
                external_url = track.get('external_url')
                
                if external_url and external_url != 'None':
                    print(f"\n[{track_num}] ✓ Descargado vía enlace externo")
                else:
                    print(f"\n[{track_num}] Descargando mejor calidad...")
                    success = download_best_audio(url, track_num)
                    if success:
                        tracks_direct_dl.append(track_num)
                    time.sleep(DELAY_BETWEEN_DOWNLOADS)
    
    # Marcar como completado
    progress['completed'] = True
    save_progress(progress)
    
    # Resumen final
    print("\n" + "="*70)
    print("📊 RESUMEN FINAL")
    print("="*70)
    print(f"✓ Total de tracks: {total_tracks}")
    print(f"✓ Con archivo original: {len(tracks_with_download)}")
    print(f"✓ Procesados con Robot: {len(tracks_for_robot)}")
    print(f"\n✅ Proceso completado. Archivos en: {DOWNLOAD_DIR}")
    print(f"\n💡 Para limpiar el progreso guardado: rm {PROGRESS_FILE}")
    
    return True


def main():
    if len(sys.argv) < 2:
        print("Uso: python script.py <URL_PLAYLIST> [--resume]")
        print("\nEjemplo:")
        print("  python script.py https://soundcloud.com/doncucho/sets/schranz-3")
        print("  python script.py https://soundcloud.com/doncucho/sets/schranz-3 --resume")
        print("\nOpciones:")
        print("  --resume    Continuar desde el último punto guardado")
        sys.exit(1)
    
    playlist_url = sys.argv[1]
    resume = '--resume' in sys.argv
    
    setup_directories()
    check_cookies_exist()
    
    success = process_playlist(playlist_url, resume)
    
    if not success:
        print("\n⚠️  Proceso interrumpido. Usa --resume para continuar:")
        print(f"     python {sys.argv[0]} {playlist_url} --resume")
        sys.exit(1)


if __name__ == "__main__":
    main()