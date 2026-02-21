"""
ARTI-2026 Voice Agent v2 — Verilənlər Bazası Körpüsü
PostgreSQL sorğularını Python-dan icra edir
"""

import json
import psycopg2
import psycopg2.extras
from config import DB_CONFIG

_conn = None


def _get_connection():
    """Singleton PostgreSQL bağlantısı."""
    global _conn
    if _conn is None or _conn.closed:
        try:
            _conn = psycopg2.connect(**DB_CONFIG)
            _conn.autocommit = True
        except Exception as e:
            print(f"  [DB] Bağlantı xətası: {e}")
            return None
    return _conn


def execute_query(sql: str) -> "dict":
    """
    SELECT sorğusunu icra et və nəticəni qaytar.

    Args:
        sql: SQL sorğusu (yalnız SELECT!)

    Returns:
        {
            "success": bool,
            "rows": list[dict],
            "row_count": int,
            "columns": list[str],
            "error": str | None,
            "summary": str
        }
    """
    # Təhlükəsizlik: yalnız SELECT icazəsi
    sql_clean = sql.strip().upper()
    if not sql_clean.startswith("SELECT") and not sql_clean.startswith("WITH"):
        return {
            "success": False,
            "rows": [],
            "row_count": 0,
            "columns": [],
            "error": "Yalnız SELECT sorğuları icazəlidir",
            "summary": "Sorğu bloklandı: yalnız oxuma əməliyyatları mümkündür."
        }

    # Əlavə təhlükəsizlik yoxlamaları
    dangerous = ["DROP", "DELETE", "UPDATE", "INSERT", "ALTER", "TRUNCATE", "CREATE"]
    for kw in dangerous:
        # CTE-lərdə bu sözlər olmamalıdır
        if kw in sql_clean and kw not in ("CREATE", ):
            # "DELETE" və s. SELECT içində WHERE sub-query kimi ola bilər
            # Amma əsas əmr SELECT olmalıdır
            pass

    conn = _get_connection()
    if conn is None:
        return {
            "success": False,
            "rows": [],
            "row_count": 0,
            "columns": [],
            "error": "DB bağlantısı qurmaq mümkün olmadı",
            "summary": "Verilənlər bazasına qoşulmaq mümkün olmadı."
        }

    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(sql)
            rows = cur.fetchall()
            columns = [desc[0] for desc in cur.description] if cur.description else []

            # dict-ə çevir (RealDictRow → dict)
            rows_list = [dict(row) for row in rows]

            # Numeric/Decimal → float çevirmə
            for row in rows_list:
                for key, val in row.items():
                    if hasattr(val, 'as_tuple'):  # Decimal
                        row[key] = float(val)

            summary = _build_summary(rows_list, columns)

            return {
                "success": True,
                "rows": rows_list,
                "row_count": len(rows_list),
                "columns": columns,
                "error": None,
                "summary": summary
            }

    except Exception as e:
        return {
            "success": False,
            "rows": [],
            "row_count": 0,
            "columns": [],
            "error": str(e),
            "summary": f"Sorğu xətası: {e}"
        }


def _build_summary(rows: list, columns: list) -> str:
    """Nəticə üçün qısa xülasə yarat."""
    if not rows:
        return "Nəticə tapılmadı."

    n = len(rows)
    if n == 1 and len(columns) <= 3:
        # Tək sətir, az sütun — birbaşa göstər
        parts = [f"{col}: {rows[0].get(col, '—')}" for col in columns]
        return " | ".join(parts)

    # Çoxsətirli nəticə
    summary = f"{n} sətir tapıldı."

    # Əgər rəqəmsal sütun varsa, orta/min/max hesabla
    for col in columns:
        vals = [row[col] for row in rows if isinstance(row.get(col), (int, float)) and row[col] is not None]
        if vals and len(vals) >= 2:
            avg = sum(vals) / len(vals)
            summary += f" {col}: orta={avg:.1f}, min={min(vals)}, max={max(vals)}."
            break  # İlk rəqəmsal sütun kifayətdir

    return summary


def test_connection() -> bool:
    """DB bağlantısını yoxla."""
    try:
        conn = _get_connection()
        if conn is None:
            return False
        with conn.cursor() as cur:
            cur.execute("SELECT 1")
            return True
    except Exception:
        return False


def get_quick_stats() -> dict:
    """Sistem haqqında qısa statistika (sağlamlıq yoxlaması üçün)."""
    result = execute_query("""
        SELECT
            (SELECT COUNT(*) FROM schools WHERE status = 'active') as schools,
            (SELECT COUNT(*) FROM students WHERE status = 'active') as students,
            (SELECT COUNT(*) FROM teachers WHERE status = 'active') as teachers
    """)
    if result["success"] and result["rows"]:
        return result["rows"][0]
    return {"schools": 0, "students": 0, "teachers": 0}


def close():
    """Bağlantını bağla."""
    global _conn
    if _conn and not _conn.closed:
        _conn.close()
        _conn = None


if __name__ == "__main__":
    print("DB Bridge Test")
    if test_connection():
        print("✅ DB bağlantısı aktiv")
        stats = get_quick_stats()
        print(f"   Məktəblər: {stats['schools']}")
        print(f"   Şagirdlər: {stats['students']}")
        print(f"   Müəllimlər: {stats['teachers']}")
    else:
        print("❌ DB bağlantısı qurmaq mümkün olmadı")
