"""
ARTI-2026 Voice Agent v2 — OpenAI TTS (Text-to-Speech)
Səsli cavab generasiyası
"""

import io
import os
import tempfile
import subprocess
import platform
from openai import OpenAI
from config import (
    OPENAI_API_KEY, TTS_MODEL, TTS_VOICE,
    TTS_SPEED, TTS_FORMAT, TTS_ENABLED,
)

_client = None


def _get_client() -> OpenAI:
    global _client
    if _client is None:
        if not OPENAI_API_KEY:
            raise RuntimeError("OPENAI_API_KEY .env faylında təyin olunmayıb")
        _client = OpenAI(api_key=OPENAI_API_KEY)
    return _client


def speak(text: str, blocking: bool = True) -> bool:
    """
    Mətni səsə çevir və oxu.

    Args:
        text: Oxunacaq mətn
        blocking: True → audio bitənə qədər gözlə

    Returns:
        Uğurlu oldu-olmadı
    """
    if not TTS_ENABLED:
        print(f"\n🔊 ARTİ: {text}")
        return True

    if not text or not text.strip():
        return False

    # Mətni TTS üçün təmizlə
    clean_text = _clean_for_tts(text)

    try:
        c = _get_client()

        # OpenAI TTS çağırışı
        response = c.audio.speech.create(
            model=TTS_MODEL,
            voice=TTS_VOICE,
            input=clean_text,
            speed=TTS_SPEED,
            response_format=TTS_FORMAT,
        )

        # Tmp faylına yaz
        suffix = f".{TTS_FORMAT}"
        tmp = tempfile.NamedTemporaryFile(suffix=suffix, delete=False)
        tmp_path = tmp.name

        # Audio datanı faylda saxla
        for chunk in response.iter_bytes(chunk_size=4096):
            tmp.write(chunk)
        tmp.close()

        # Konsola mətni göstər
        print(f"\n🔊 ARTİ: {text}")

        # Audio-nu çal
        _play_audio(tmp_path, blocking=blocking)

        # Təmizlə
        try:
            os.unlink(tmp_path)
        except OSError:
            pass

        return True

    except Exception as e:
        print(f"\n🔊 ARTİ: {text}")
        print(f"  [TTS xəta: {e}]")
        return False


def _clean_for_tts(text: str) -> str:
    """Mətni TTS üçün optimallaşdır."""
    import re
    result = text

    # Rəqəmləri sözlərlə əvəzləmə (Azərbaycan üçün əsas olanlar)
    result = re.sub(r"(\d+)%", r"\1 faiz", result)

    # Texniki simvolları sil
    result = re.sub(r"[#*_`~]", "", result)

    # Çox uzun mətni kəs (TTS limiti ~4096 simvol)
    if len(result) > 3500:
        # Son tam cümlədə kəs
        result = result[:3500]
        last_period = result.rfind(".")
        if last_period > 2000:
            result = result[:last_period + 1]

    return result.strip()


def _play_audio(filepath: str, blocking: bool = True):
    """Platforma üzrə audio faylını çal."""
    system = platform.system()

    try:
        if system == "Darwin":
            # macOS — afplay
            cmd = ["afplay", filepath]
        elif system == "Linux":
            # Linux — mpv, ffplay, və ya aplay
            for player in ["mpv", "ffplay", "aplay"]:
                if _command_exists(player):
                    if player == "mpv":
                        cmd = ["mpv", "--no-video", "--really-quiet", filepath]
                    elif player == "ffplay":
                        cmd = ["ffplay", "-nodisp", "-autoexit", "-loglevel", "quiet", filepath]
                    else:
                        cmd = ["aplay", filepath]
                    break
            else:
                print("  [TTS] Audio player tapılmadı (mpv, ffplay, aplay lazımdır)")
                return
        elif system == "Windows":
            # Windows — PowerShell
            cmd = ["powershell", "-c",
                   f"(New-Object Media.SoundPlayer '{filepath}').PlaySync()"]
        else:
            print(f"  [TTS] Dəstəklənməyən platform: {system}")
            return

        if blocking:
            subprocess.run(cmd, capture_output=True)
        else:
            subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    except FileNotFoundError:
        print("  [TTS] Audio player tapılmadı")
    except Exception as e:
        print(f"  [TTS] Audio çalma xətası: {e}")


def _command_exists(cmd: str) -> bool:
    """Əmrin mövcudluğunu yoxla."""
    try:
        subprocess.run(["which", cmd], capture_output=True, check=True)
        return True
    except (subprocess.CalledProcessError, FileNotFoundError):
        return False


def test_tts():
    """TTS sistemini test et."""
    print(f"TTS Model: {TTS_MODEL}")
    print(f"TTS Səs: {TTS_VOICE}")
    print(f"TTS Sürət: {TTS_SPEED}")
    print(f"TTS Aktiv: {TTS_ENABLED}")
    print(f"Platform: {platform.system()}")
    print(f"API açar: {'***' + OPENAI_API_KEY[-4:] if OPENAI_API_KEY else 'TƏYİN OLUNMAYIB'}")

    if TTS_ENABLED and OPENAI_API_KEY:
        print("\nTest cümləsi oxunur...")
        speak("Salam, mən ARTİ-yəm. Təhsil idarəetmə sisteminin səsli köməkçisiyəm.")
    elif not TTS_ENABLED:
        print("\n[TTS deaktiv — yalnız konsol çıxışı]")
    else:
        print("\n[OPENAI_API_KEY lazımdır]")


if __name__ == "__main__":
    test_tts()
