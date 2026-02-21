"""
ARTI-2026 Voice Agent v2 — AI Beyin
Claude API ilə əmr analizi, DB sorğusu, təbii dildə cavab generasiyası
"""

import re
import anthropic
from config import (
    CLAUDE_API_KEY, CLAUDE_MODEL, CLAUDE_MAX_TOKENS,
    CLAUDE_TEMPERATURE, SYSTEM_PROMPT,
)
from db_bridge import execute_query
from context import ConversationContext

_client = None


def _get_client() -> anthropic.Anthropic:
    global _client
    if _client is None:
        if not CLAUDE_API_KEY:
            raise RuntimeError("CLAUDE_API_KEY .env faylında təyin olunmayıb")
        _client = anthropic.Anthropic(api_key=CLAUDE_API_KEY)
    return _client


def think(user_text: str, context: ConversationContext) -> dict:
    """
    İstifadəçi sualını analiz et → DB sorğusu → Claude cavabı.
    Tam "düşüncə" dövrü.

    Args:
        user_text: Transkripsiya olunmuş sual
        context: Söhbət konteksti

    Returns:
        {
            "answer": str,          # Səsli oxunacaq cavab
            "sql": str | None,      # İcra olunan SQL (əgər varsa)
            "db_result": dict|None, # DB nəticəsi
            "raw_response": str,    # Claude-un tam cavabı
            "success": bool,
        }
    """
    # Wake word-u təmizlə
    clean_text = _remove_wake_word(user_text)
    if not clean_text.strip():
        return {
            "answer": "Bəli, dinləyirəm. Sualınızı verin.",
            "sql": None, "db_result": None,
            "raw_response": "", "success": True,
        }

    # Kontekstə əlavə et
    context.add_user_message(clean_text)

    # Sistem promptuna kontekst xülasəsi əlavə et
    ctx_summary = context.get_context_summary()
    full_system = SYSTEM_PROMPT
    if ctx_summary:
        full_system += f"\n\n{ctx_summary}"

    # Claude-a göndər
    c = _get_client()
    try:
        response = c.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=CLAUDE_MAX_TOKENS,
            temperature=CLAUDE_TEMPERATURE,
            system=full_system,
            messages=context.get_claude_messages(),
        )

        raw = response.content[0].text.strip()

        # SQL sorğusu çıxar
        sql = _extract_sql(raw)
        db_result = None

        if sql:
            print(f"  🔍 DB sorğusu icra olunur...")
            db_result = execute_query(sql)

            if db_result["success"]:
                print(f"  ✅ {db_result['row_count']} sətir tapıldı")
                # Nəticəni Claude-a geri göndər — dəqiq cavab üçün
                answer = _refine_answer_with_data(c, clean_text, raw, db_result, context)
            else:
                print(f"  ❌ DB xətası: {db_result['error']}")
                # SQL xətası — Claude-un öz cavabını istifadə et
                answer = _extract_answer(raw)
                if not answer:
                    answer = "Verilənlər bazasına müraciət zamanı xəta baş verdi. Sualı fərqli formada verin."
        else:
            answer = _extract_answer(raw)
            if not answer:
                answer = raw  # Fallback

        # Kontekstə əlavə et
        context.add_assistant_message(answer, sql=sql, db_result=db_result)

        return {
            "answer": answer,
            "sql": sql,
            "db_result": db_result,
            "raw_response": raw,
            "success": True,
        }

    except Exception as e:
        error_msg = f"AI xətası baş verdi: {e}"
        print(f"  [XƏTA] Claude API: {e}")
        return {
            "answer": "Bağışlayın, cavab hazırlaya bilmədim. Yenidən cəhd edin.",
            "sql": None, "db_result": None,
            "raw_response": str(e), "success": False,
        }


def _refine_answer_with_data(client, question: str, initial_response: str,
                              db_result: dict, context: ConversationContext) -> str:
    """
    DB nəticəsi ilə dəqiq cavab yarat.
    Claude-a DB nəticəsini göndərir, qısa səsli cavab alır.
    """
    # DB nəticəsini formatla
    rows = db_result["rows"]
    if not rows:
        return "Sorğu icra olundu, amma nəticə tapılmadı."

    # Nəticəni mətn formatına çevir (maks 15 sətir)
    data_text = _format_db_result(rows, db_result["columns"])

    refine_prompt = f"""İstifadəçinin sualı: "{question}"

DB sorğusu nəticəsi:
{data_text}

Bu nəticəyə əsasən qısa (2-3 cümlə) Azərbaycan dilində cavab yaz.
Rəqəmləri dəqiq istifadə et. CAVAB: prefiksi ilə başla."""

    try:
        response = client.messages.create(
            model=CLAUDE_MODEL,
            max_tokens=512,
            temperature=0.4,
            system="Sən ARTI-2026 səsli köməkçisisən. Qısa, konkret cavab ver. Yalnız CAVAB: hissəsini yaz.",
            messages=[{"role": "user", "content": refine_prompt}]
        )
        refined = response.content[0].text.strip()
        answer = _extract_answer(refined)
        return answer if answer else refined
    except Exception:
        # Fallback — ilkin cavabdan CAVAB çıxar
        answer = _extract_answer(initial_response)
        if answer:
            return answer
        return db_result.get("summary", "Nəticə alındı.")


def _extract_sql(text: str) -> "str | None":
    """Claude cavabından SQL sorğusunu çıxar."""
    # ```sql_query ... ``` bloku
    match = re.search(r"```sql_query\s*\n(.+?)```", text, re.DOTALL)
    if match:
        return match.group(1).strip()

    # ```sql ... ``` bloku
    match = re.search(r"```sql\s*\n(.+?)```", text, re.DOTALL)
    if match:
        sql = match.group(1).strip()
        if sql.upper().startswith(("SELECT", "WITH")):
            return sql

    return None


def _extract_answer(text: str) -> "str | None":
    """Claude cavabından CAVAB: hissəsini çıxar."""
    # "CAVAB:" etiketini axtar
    match = re.search(r"CAVAB:\s*(.+)", text, re.DOTALL)
    if match:
        answer = match.group(1).strip()
        # SQL bloklarını təmizlə
        answer = re.sub(r"```[\s\S]*?```", "", answer).strip()
        return answer
    return None


def _remove_wake_word(text: str) -> str:
    """Mətndən wake word-u sil."""
    patterns = [
        r"(?i)^(hey\s+)?(arti|artı|agent)\s*[,.]?\s*",
        r"(?i)^(hey\s+)?(arti|artı|agent)\b\s*",
    ]
    result = text
    for pattern in patterns:
        result = re.sub(pattern, "", result)
    return result.strip()


def _format_db_result(rows: list, columns: list) -> str:
    """DB nəticəsini oxunaqlı mətnə çevir."""
    if not rows:
        return "Nəticə yoxdur"

    lines = []
    # Başlıq
    lines.append(" | ".join(columns))
    lines.append("-" * (len(" | ".join(columns))))

    # Sətrlər (maks 15)
    for row in rows[:15]:
        vals = []
        for col in columns:
            v = row.get(col, "")
            if isinstance(v, float):
                v = f"{v:.1f}"
            vals.append(str(v) if v is not None else "—")
        lines.append(" | ".join(vals))

    if len(rows) > 15:
        lines.append(f"... və daha {len(rows) - 15} sətir")

    return "\n".join(lines)


# =============================================
# XÜSUSİ ƏMRLƏR (DB-dən asılı olmayan)
# =============================================

SPECIAL_COMMANDS = {
    "salam": "Salam! Mən ARTİ, təhsil idarəetmə sisteminin səsli köməkçisiyəm. Nə ilə kömək edə bilərəm?",
    "necəsən": "Yaxşıyam, sağ olun! Suallarınızı gözləyirəm.",
    "sağ ol": "Buyurun! Başqa sualınız varsa, hazıram.",
    "tesekkur": "Dəyməz! Hər zaman kömək etməyə hazıram.",
    "təşəkkür": "Dəyməz! Hər zaman kömək etməyə hazıram.",
}


def check_special_command(text: str) -> "str | None":
    """Xüsusi əmrləri yoxla (DB/AI olmadan cavab)."""
    text_lower = text.lower().strip()
    for key, response in SPECIAL_COMMANDS.items():
        if key in text_lower:
            return response
    return None


if __name__ == "__main__":
    # Test
    from context import ConversationContext
    ctx = ConversationContext()

    test_questions = [
        "ARTI, bu həftə neçə şagird qayıb olub?",
        "Ən çox hansı məktəbdə?",
        "Riyaziyyatdan orta bal neçədir?",
    ]
    print(f"Model: {CLAUDE_MODEL}")
    print(f"API açar: {'***' + CLAUDE_API_KEY[-4:] if CLAUDE_API_KEY else 'TƏYİN OLUNMAYIB'}\n")

    if CLAUDE_API_KEY:
        for q in test_questions:
            print(f"\n❓ {q}")
            result = think(q, ctx)
            print(f"💬 {result['answer']}")
            if result["sql"]:
                print(f"🔍 SQL: {result['sql'][:80]}...")
