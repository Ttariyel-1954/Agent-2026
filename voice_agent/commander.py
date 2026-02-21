"""
ARTI-2026 Voice Agent v2 — Shell Əmr Çeviricisi (v1 uyğunluğu)
Yalnız --exec rejimində istifadə olunur (shell əmrləri üçün)
"""

import re
import anthropic
from config import (
    CLAUDE_API_KEY, CLAUDE_MODEL, CLAUDE_MAX_TOKENS,
    PROJECT_ROOT, BLOCKED_PATTERNS,
)

_client = None

# Shell əmr rejimi üçün xüsusi prompt
COMMANDER_PROMPT = f"""Sən ARTI-2026 layihəsinin şəll köməkçisisən.
İstifadəçinin Azərbaycan və ya İngilis dilindəki əmrini shell əmrinə çevir.
Yalnız BİR shell əmri qaytar, izahat vermə.
Əgər əmr aydın deyilsə, "AYDIN_DEYIL: [sual]" formatında cavab ver.

Layihə: {PROJECT_ROOT}
Texnologiya: R Shiny, PostgreSQL, Python
DB: psql "postgresql://$DB_USER:$DB_PASSWORD@$DB_HOST:$DB_PORT/$DB_NAME"
"""


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        if not CLAUDE_API_KEY:
            raise RuntimeError("CLAUDE_API_KEY .env faylında təyin olunmayıb")
        _client = anthropic.Anthropic(api_key=CLAUDE_API_KEY)
    return _client


def text_to_command(user_text: str) -> dict:
    """
    İstifadəçi mətnini shell əmrinə çevir (v1 uyğunluğu).

    Returns:
        {
            "command": str | None,
            "explanation": str,
            "is_clear": bool,
            "question": str | None
        }
    """
    c = _get_client()

    try:
        response = c.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=CLAUDE_MAX_TOKENS,
            system=COMMANDER_PROMPT,
            messages=[{
                "role": "user",
                "content": f"Bu əmri shell əmrinə çevir: \"{user_text}\"\n\n"
                           f"Cavab formatı:\nEMR: <shell əmri>\nvə ya\nAYDIN_DEYIL: <sual>\n\n"
                           f"Layihə qovluğu: {PROJECT_ROOT}",
            }],
        )

        reply = response.content[0].text.strip()

        if reply.startswith("AYDIN_DEYIL:"):
            question = reply.replace("AYDIN_DEYIL:", "").strip()
            return {
                "command": None,
                "explanation": "Əmr aydın deyil",
                "is_clear": False,
                "question": question,
            }

        if reply.startswith("EMR:"):
            cmd = reply.replace("EMR:", "").strip()
        else:
            code_match = re.search(r"```(?:bash|sh)?\s*\n(.+?)```", reply, re.DOTALL)
            if code_match:
                cmd = code_match.group(1).strip()
            else:
                cmd = reply.split("\n")[0].strip()

            if not any(c in cmd for c in " /.|&;$~"):
                return {
                    "command": None,
                    "explanation": reply,
                    "is_clear": False,
                    "question": "Nə etmək istəyirsiniz?",
                }

        return {
            "command": cmd,
            "explanation": f"\"{user_text}\" → {cmd}",
            "is_clear": True,
            "question": None,
        }

    except Exception as e:
        return {
            "command": None,
            "explanation": f"API xətası: {e}",
            "is_clear": False,
            "question": None,
        }


if __name__ == "__main__":
    test_phrases = [
        "Tətbiqi işə sal",
        "Son 5 commiti göstər",
        "Müəllim sayını göstər",
    ]
    print(f"Commander v2 (shell rejim)")
    print(f"Model: {CLAUDE_MODEL}")
    if CLAUDE_API_KEY:
        for phrase in test_phrases:
            print(f"\n>>> {phrase}")
            result = text_to_command(phrase)
            print(f"    Əmr: {result['command']}")
