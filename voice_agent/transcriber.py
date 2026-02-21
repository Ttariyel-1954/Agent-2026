"""
ARTI-2026 Voice Agent v2 — Whisper STT
Azərbaycan/Türk dili optimizasiyası ilə Speech-to-Text
"""

import io
from openai import OpenAI
from config import (
    OPENAI_API_KEY, WHISPER_MODEL,
    WHISPER_LANGUAGE, WHISPER_LANGUAGE_FALLBACK,
    WHISPER_PROMPT,
)

_client = None


def _get_client() -> OpenAI:
    global _client
    if _client is None:
        if not OPENAI_API_KEY:
            raise RuntimeError("OPENAI_API_KEY .env faylında təyin olunmayıb")
        _client = OpenAI(api_key=OPENAI_API_KEY)
    return _client


def transcribe(audio_bytes: bytes, quiet: bool = False) -> "str | None":
    """
    WAV audio baytlarını mətnə çevir (Whisper API).
    Azərbaycan dili optimizasiyası ilə.

    Args:
        audio_bytes: WAV formatında audio
        quiet: True — konsola yazmadan (wake word yoxlaması üçün)

    Returns:
        Transkripsiya olunmuş mətn və ya None
    """
    c = _get_client()

    audio_file = io.BytesIO(audio_bytes)
    audio_file.name = "recording.wav"

    try:
        # İlk cəhd: Azərbaycan dili
        params = {
            "model": WHISPER_MODEL,
            "file": audio_file,
            "response_format": "text",
            "prompt": WHISPER_PROMPT,
            "language": WHISPER_LANGUAGE,
        }

        try:
            result = c.audio.transcriptions.create(**params)
        except Exception:
            # "az" dəstəklənmirsə "tr" ilə yenidən cəhd et
            if WHISPER_LANGUAGE_FALLBACK and WHISPER_LANGUAGE != WHISPER_LANGUAGE_FALLBACK:
                if not quiet:
                    print(f"  [Whisper] '{WHISPER_LANGUAGE}' → '{WHISPER_LANGUAGE_FALLBACK}' fallback")
                audio_file.seek(0)
                params["language"] = WHISPER_LANGUAGE_FALLBACK
                result = c.audio.transcriptions.create(**params)
            else:
                raise

        text = result.strip() if isinstance(result, str) else result.text.strip()

        if not text:
            if not quiet:
                print("  [Whisper] Boş transkripsiya")
            return None

        # Post-processing: Azərbaycan dili düzəlişləri
        text = _post_process_az(text)

        if not quiet:
            print(f"\n📝 Eşitdim: \"{text}\"")

        return text

    except Exception as e:
        if not quiet:
            print(f"  [XƏTA] Whisper API: {e}")
        return None


def _post_process_az(text: str) -> str:
    """
    Whisper çıxışını Azərbaycan dili üçün düzəlt.
    Tez-tez olan transkripsiya xətalarını aradan qaldır.
    """
    replacements = {
        # Whisper tez-tez Türkcə çevirir
        "öğrenci": "şagird",
        "öğretmen": "müəllim",
        "okul": "məktəb",
        "sınıf": "sinif",
        "ders": "dərs",
        "not": "qiymət",
        "devamsızlık": "davamiyyət",
        "yoklama": "davamiyyət",
        "rapor": "hesabat",
        "ortalama": "ortalama",
        # Wake word düzəlişləri
        "artık": "ARTI",
        "artı": "ARTI",
        "art": "ARTI",
        "aren't": "ARTI",
        "arty": "ARTI",
    }

    result = text
    for old, new in replacements.items():
        # Case-insensitive replace
        idx = result.lower().find(old.lower())
        while idx != -1:
            result = result[:idx] + new + result[idx + len(old):]
            idx = result.lower().find(old.lower(), idx + len(new))

    return result


if __name__ == "__main__":
    print("Transcriber modulu v2")
    print(f"Model: {WHISPER_MODEL}")
    print(f"Dil: {WHISPER_LANGUAGE} (fallback: {WHISPER_LANGUAGE_FALLBACK})")
    print(f"Prompt: {WHISPER_PROMPT[:80]}...")
    print(f"API açar: {'***' + OPENAI_API_KEY[-4:] if OPENAI_API_KEY else 'TƏYİN OLUNMAYIB'}")
