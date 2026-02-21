"""
ARTI-2026 Voice Agent v2 — Söhbət Konteksti
Əvvəlki sualları yadda saxlayır, kontekstli söhbət imkanı verir
"""

import json
import time
from pathlib import Path
from config import CONTEXT_WINDOW, CONTEXT_FILE


class ConversationContext:
    """
    Söhbət tarixçəsi idarəetməsi.
    - Son N mesajı yadda saxlayır
    - Faylda persist edir (sessiyalar arası)
    - Claude API üçün messages formatında çıxarır
    """

    def __init__(self, max_messages: int = None, persist_file: Path = None):
        self.max_messages = max_messages or CONTEXT_WINDOW
        self.persist_file = persist_file or CONTEXT_FILE
        self.messages = []
        self.session_start = time.time()
        self.turn_count = 0

        # Əvvəlki sessiyadan yüklə
        self._load()

    def add_user_message(self, text: str):
        """İstifadəçi mesajı əlavə et."""
        self.messages.append({
            "role": "user",
            "content": text,
            "timestamp": time.time(),
        })
        self.turn_count += 1
        self._trim()
        self._save()

    def add_assistant_message(self, text: str, sql: str = None, db_result: dict = None):
        """ARTİ cavabı əlavə et."""
        entry = {
            "role": "assistant",
            "content": text,
            "timestamp": time.time(),
        }
        if sql:
            entry["sql"] = sql
        if db_result:
            entry["db_summary"] = db_result.get("summary", "")
        self.messages.append(entry)
        self._trim()
        self._save()

    def get_claude_messages(self) -> list:
        """
        Claude API üçün messages formatında qaytar.
        Yalnız role + content saxlanır.
        """
        result = []
        for msg in self.messages:
            result.append({
                "role": msg["role"],
                "content": msg["content"],
            })
        return result

    def get_context_summary(self) -> str:
        """
        Son söhbətin qısa xülasəsi (sistem promptuna əlavə etmək üçün).
        """
        if not self.messages:
            return ""

        recent = self.messages[-6:]  # Son 3 turn (6 mesaj)
        lines = ["Son söhbət konteksti:"]
        for msg in recent:
            prefix = "İstifadəçi" if msg["role"] == "user" else "ARTİ"
            content = msg["content"][:150]
            lines.append(f"  {prefix}: {content}")

        return "\n".join(lines)

    def clear(self):
        """Söhbəti təmizlə."""
        self.messages = []
        self.turn_count = 0
        self.session_start = time.time()
        self._save()
        print("🗑  Söhbət tarixçəsi təmizləndi")

    def get_stats(self) -> dict:
        """Söhbət statistikası."""
        user_msgs = sum(1 for m in self.messages if m["role"] == "user")
        asst_msgs = sum(1 for m in self.messages if m["role"] == "assistant")
        duration = time.time() - self.session_start
        return {
            "total_messages": len(self.messages),
            "user_messages": user_msgs,
            "assistant_messages": asst_msgs,
            "turns": self.turn_count,
            "session_duration_min": round(duration / 60, 1),
        }

    def _trim(self):
        """Kontekst pəncərəsini aş."""
        while len(self.messages) > self.max_messages:
            self.messages.pop(0)

    def _save(self):
        """Tarixçəni faylda saxla."""
        try:
            data = {
                "session_start": self.session_start,
                "turn_count": self.turn_count,
                "messages": self.messages,
            }
            self.persist_file.write_text(
                json.dumps(data, ensure_ascii=False, indent=2, default=str),
                encoding="utf-8"
            )
        except Exception as e:
            pass  # Fayl yazma xətası kritik deyil

    def _load(self):
        """Əvvəlki sessiyadan yüklə."""
        try:
            if self.persist_file.exists():
                data = json.loads(self.persist_file.read_text(encoding="utf-8"))
                # Yalnız son 1 saat ərzindəki mesajları yüklə
                last_ts = data.get("session_start", 0)
                if time.time() - last_ts < 3600:
                    self.messages = data.get("messages", [])
                    self.turn_count = data.get("turn_count", 0)
                    self.session_start = last_ts
                    if self.messages:
                        n = len(self.messages)
                        print(f"  📋 Əvvəlki sessiyadan {n} mesaj yükləndi")
        except Exception:
            pass  # Yükləmə xətası kritik deyil


if __name__ == "__main__":
    ctx = ConversationContext()
    print("Kontekst test:")
    ctx.add_user_message("Bu həftə neçə şagird qayıb olub?")
    ctx.add_assistant_message("Bu həftə 47 şagird qayıb qeydə alınıb.",
                              sql="SELECT COUNT(*) FROM attendance WHERE status='qayıb'")
    ctx.add_user_message("Ən çox hansı məktəbdə?")
    ctx.add_assistant_message("Ən çox Məktəb 12-dədir — 8 şagird.")

    print("\nClaude messages:")
    for m in ctx.get_claude_messages():
        print(f"  {m['role']}: {m['content']}")

    print(f"\nStats: {ctx.get_stats()}")
    print(f"\nContext summary:\n{ctx.get_context_summary()}")
