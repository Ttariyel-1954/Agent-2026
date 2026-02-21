"""
ARTI-2026 Voice Agent v2 — Mikrofon Dinləmə + Wake Word Detection
Dövri dinləmə rejimi: "ARTI" və ya "Agent" sözünü algılayır
"""

import io
import struct
import time
import wave
import pyaudio
from config import (
    SAMPLE_RATE, CHANNELS, CHUNK_SIZE,
    SILENCE_THRESHOLD, SILENCE_DURATION, MAX_RECORD_SECONDS,
    WAKE_WORDS, CONTINUOUS_LISTEN,
)


def get_rms(data: bytes) -> float:
    """Audio chunk-un RMS (Root Mean Square) seviyyesini hesabla."""
    count = len(data) // 2
    if count == 0:
        return 0
    shorts = struct.unpack(f"<{count}h", data)
    sum_squares = sum(s * s for s in shorts)
    return (sum_squares / count) ** 0.5


def list_microphones():
    """Movcud mikrofonlari siyahila."""
    pa = pyaudio.PyAudio()
    print("\nMövcud audio cihazları:")
    for i in range(pa.get_device_count()):
        info = pa.get_device_info_by_index(i)
        if info["maxInputChannels"] > 0:
            print(f"  [{i}] {info['name']} (girişləri: {info['maxInputChannels']})")
    pa.terminate()


def listen(device_index=None) -> "bytes | None":
    """
    Mikrofonu dinlə, səs algılananda qeydə başla,
    susma müddətindən sonra dayandır.

    Returns:
        WAV formatında audio baytları və ya None
    """
    pa = pyaudio.PyAudio()

    try:
        stream = pa.open(
            format=pyaudio.paInt16,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            input_device_index=device_index,
            frames_per_buffer=CHUNK_SIZE,
        )
    except OSError as e:
        print(f"[XƏTA] Mikrofon açıla bilmədi: {e}")
        pa.terminate()
        return None

    print("🎤 Dinləyirəm... (danışmağa başlayın)")

    frames = []
    recording = False
    silence_start = None
    start_time = time.time()

    try:
        while True:
            elapsed = time.time() - start_time
            if elapsed > MAX_RECORD_SECONDS:
                if recording:
                    print(f"\n⏱  Maksimum müddət ({MAX_RECORD_SECONDS}s) keçdi")
                    break
                else:
                    stream.stop_stream()
                    stream.close()
                    pa.terminate()
                    return None

            data = stream.read(CHUNK_SIZE, exception_on_overflow=False)
            rms = get_rms(data)

            if rms > SILENCE_THRESHOLD:
                if not recording:
                    recording = True
                    print("🔴 Qeyd olunur...", end="", flush=True)
                silence_start = None
                frames.append(data)
            elif recording:
                frames.append(data)
                if silence_start is None:
                    silence_start = time.time()
                elif time.time() - silence_start > SILENCE_DURATION:
                    print(" tamamlandı!")
                    break
    except KeyboardInterrupt:
        print("\n[Dayandırıldı]")
        if not frames:
            stream.stop_stream()
            stream.close()
            pa.terminate()
            return None

    stream.stop_stream()
    stream.close()
    pa.terminate()

    if not frames:
        return None

    buf = io.BytesIO()
    with wave.open(buf, "wb") as wf:
        wf.setnchannels(CHANNELS)
        wf.setsampwidth(2)
        wf.setframerate(SAMPLE_RATE)
        wf.writeframes(b"".join(frames))

    duration = len(frames) * CHUNK_SIZE / SAMPLE_RATE
    print(f"   Qeyd müddəti: {duration:.1f} saniyə")
    return buf.getvalue()


def listen_continuous(device_index=None, on_speech=None, transcribe_fn=None):
    """
    Dövri dinləmə — Wake word algılama rejimi.
    Mikrofon daim açıqdır. Ses algılananda qısa fraqment qeyd olunur,
    Whisper ilə transkripsiya edilir və wake word yoxlanılır.

    Args:
        device_index: Mikrofon indeksi
        on_speech: callback(audio_bytes) — wake word-dan sonra tam audio üçün
        transcribe_fn: Whisper transkripsiya funksiyası (quick check üçün)

    Yields:
        audio_bytes — wake word algılandıqdan sonra tam söz/cümlə
    """
    pa = pyaudio.PyAudio()

    try:
        stream = pa.open(
            format=pyaudio.paInt16,
            channels=CHANNELS,
            rate=SAMPLE_RATE,
            input=True,
            input_device_index=device_index,
            frames_per_buffer=CHUNK_SIZE,
        )
    except OSError as e:
        print(f"[XƏTA] Mikrofon açıla bilmədi: {e}")
        pa.terminate()
        return

    print("👂 Dövri dinləmə aktiv — \"ARTİ\" və ya \"Agent\" deyin")
    print("   Ctrl+C — dayandır\n")

    # Bufer — son 2 saniyəlik audio saxlanır (wake word detect üçün)
    buffer_seconds = 2.0
    buffer_chunks = int(buffer_seconds * SAMPLE_RATE / CHUNK_SIZE)
    audio_buffer = []
    active = False
    active_frames = []
    silence_start = None

    try:
        while True:
            data = stream.read(CHUNK_SIZE, exception_on_overflow=False)
            rms = get_rms(data)

            if active:
                # Wake word algılanıb, tam cümləni qeyd et
                active_frames.append(data)

                if rms <= SILENCE_THRESHOLD:
                    if silence_start is None:
                        silence_start = time.time()
                    elif time.time() - silence_start > SILENCE_DURATION:
                        # Sustu — qeyd tamamlandı
                        print(" tamamlandı!")
                        buf = io.BytesIO()
                        with wave.open(buf, "wb") as wf:
                            wf.setnchannels(CHANNELS)
                            wf.setsampwidth(2)
                            wf.setframerate(SAMPLE_RATE)
                            wf.writeframes(b"".join(active_frames))

                        audio_bytes = buf.getvalue()
                        active = False
                        active_frames = []
                        silence_start = None

                        if on_speech:
                            on_speech(audio_bytes)
                        else:
                            yield audio_bytes
                else:
                    silence_start = None

                # Maksimum müddət
                if len(active_frames) * CHUNK_SIZE / SAMPLE_RATE > MAX_RECORD_SECONDS:
                    print("\n⏱  Maksimum müddət keçdi")
                    active = False
                    active_frames = []
                    silence_start = None

            else:
                # Passiv rejim — audio buferi saxla
                audio_buffer.append(data)
                if len(audio_buffer) > buffer_chunks:
                    audio_buffer.pop(0)

                # Əgər ses algılanırsa, wake word yoxla
                if rms > SILENCE_THRESHOLD and len(audio_buffer) >= 3:
                    # Qısa fraqment götür və transkripsiya et
                    if transcribe_fn and len(audio_buffer) > 10:
                        # Son 1.5 saniyəlik audio-nu yoxla
                        check_frames = audio_buffer[-int(1.5 * SAMPLE_RATE / CHUNK_SIZE):]
                        check_buf = io.BytesIO()
                        with wave.open(check_buf, "wb") as wf:
                            wf.setnchannels(CHANNELS)
                            wf.setsampwidth(2)
                            wf.setframerate(SAMPLE_RATE)
                            wf.writeframes(b"".join(check_frames))

                        snippet_text = transcribe_fn(check_buf.getvalue(), quiet=True)
                        if snippet_text and _contains_wake_word(snippet_text):
                            print(f"\n🔔 Wake word algılandı: \"{snippet_text}\"")
                            print("🔴 Sualınızı verin...", end="", flush=True)
                            active = True
                            active_frames = list(audio_buffer)
                            audio_buffer = []
                            silence_start = None

    except KeyboardInterrupt:
        print("\n\n👋 Dövri dinləmə dayandırıldı")
    finally:
        stream.stop_stream()
        stream.close()
        pa.terminate()


def _contains_wake_word(text: str) -> bool:
    """Mətndə wake word olub-olmadığını yoxla."""
    text_lower = text.lower().strip()
    # Türk/Azərbaycan əlifbası normallaşdırması
    text_normalized = (
        text_lower
        .replace("ı", "i")
        .replace("ə", "e")
        .replace("ö", "o")
        .replace("ü", "u")
        .replace("ş", "s")
        .replace("ç", "c")
        .replace("ğ", "g")
    )
    for wake in WAKE_WORDS:
        wake_norm = (
            wake.lower()
            .replace("ı", "i")
            .replace("ə", "e")
            .replace("ö", "o")
            .replace("ü", "u")
            .replace("ş", "s")
            .replace("ç", "c")
            .replace("ğ", "g")
        )
        if wake_norm in text_normalized:
            return True
    return False


# Moduldan birbaşa test
if __name__ == "__main__":
    import sys
    if "--list" in sys.argv:
        list_microphones()
    elif "--continuous" in sys.argv:
        print("Dövri dinləmə test rejimi (wake word olmadan)...")
        for audio in listen_continuous():
            print(f"  Audio alındı: {len(audio)} bayt")
    else:
        audio = listen()
        if audio:
            print(f"Audio ölçüsü: {len(audio)} bayt")
        else:
            print("Səs algılanmadı")
