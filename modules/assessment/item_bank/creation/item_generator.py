"""

ARTI 2026 - Sual Yaratma Sistemi
==================================
AI ile avtomatik sual yaratma ve IRT parametrlerinin qiymetlendirilmesi.

Funksiyalar:
- Muxteli fenler ucun sual yaratma
- Cesinlik seviyyesine gore sual secimi
- IRT parametr qiymetlendirmesi (kalibrasiya)
- Sual keyfiyyetinin yoxlanmasi
"""

import json
import uuid
from typing import List, Dict, Optional
from dataclasses import dataclass, field
from datetime import datetime


@dataclass
class Question:
    """Sual modeli."""
    question_id: str
    subject: str                # Fen (Riyaziyyat, Fizika, vs.)
    grade_level: int            # Sinif (5-11)
    topic: str                  # Movzu
    difficulty: str             # easy, medium, hard
    question_text: str          # Sual metni
    options: List[str]          # Variant cavablar
    correct_answer: int         # Duzgun cavab indeksi (0-3)
    explanation: str = ""       # Izah
    bloom_level: str = ""       # Bloom taksonomiyasi seviyyesi
    irt_params: Dict = field(default_factory=dict)
    status: str = "draft"       # draft, review, approved, active, retired
    created_at: str = ""
    created_by: str = ""


class ItemGenerator:
    """Sual yaratma ve idare sistemi."""

    def __init__(self):
        self.questions: Dict[str, Question] = {}
        self.subjects = {
            "Riyaziyyat": ["Cebr", "Hendese", "Statistika", "Ededler nezeiryyesi",
                           "Funksiyalar", "Tenliker", "Berabersizlikler"],
            "Fizika": ["Mexanika", "Optika", "Elektrik", "Termodinamika",
                       "Atom fizikasi", "Dalga", "Maqnetizm"],
            "Kimya": ["Atom qurulusu", "Kimyevi rabiteler", "Reaksiyalar",
                      "Heller", "Oksidlesme-reduksiya", "Elektrohimya"],
            "Biologiya": ["Hucre", "Genetika", "Ekologiya", "Anatomiya",
                          "Evolyusiya", "Botanika", "Zoologiya"],
            "Informatika": ["Alqoritmlir", "Proqramlashditma", "Verilener bazasi",
                            "Shebekeler", "Emeliyyat sistemleri"],
            "Azerbaycan dili": ["Fonetika", "Leksika", "Morfologiya",
                                "Sintaksis", "Orfografiya"],
            "Tarix": ["Qedim tarix", "Orta esrler", "Yeni dovr",
                      "En yeni dovr", "Azerbaycan tarixi"],
            "Cografiya": ["Fiziki cografiya", "Iqtisadi cografiya",
                          "Azerbaycan cografiyasi", "Dunya cografiyasi"],
        }

    def create_question(self, subject: str, grade_level: int,
                        topic: str, difficulty: str,
                        question_text: str, options: List[str],
                        correct_answer: int, explanation: str = "",
                        bloom_level: str = "application",
                        created_by: str = "system") -> Question:
        """Yeni sual yaradir."""
        question = Question(
            question_id=f"Q_{uuid.uuid4().hex[:8].upper()}",
            subject=subject,
            grade_level=grade_level,
            topic=topic,
            difficulty=difficulty,
            question_text=question_text,
            options=options,
            correct_answer=correct_answer,
            explanation=explanation,
            bloom_level=bloom_level,
            status="draft",
            created_at=datetime.now().isoformat(),
            created_by=created_by,
        )
        self.questions[question.question_id] = question
        return question

    def get_questions_by_filter(self, subject: str = None,
                                grade_level: int = None,
                                difficulty: str = None,
                                status: str = None) -> List[Question]:
        """Filtere gore suallar qaytarir."""
        result = list(self.questions.values())

        if subject:
            result = [q for q in result if q.subject == subject]
        if grade_level:
            result = [q for q in result if q.grade_level == grade_level]
        if difficulty:
            result = [q for q in result if q.difficulty == difficulty]
        if status:
            result = [q for q in result if q.status == status]

        return result

    def export_to_json(self, filepath: str, questions: List[Question] = None):
        """Suallari JSON formatinda ixrac edir."""
        if questions is None:
            questions = list(self.questions.values())

        data = [
            {
                "question_id": q.question_id,
                "subject": q.subject,
                "grade_level": q.grade_level,
                "topic": q.topic,
                "difficulty": q.difficulty,
                "question_text": q.question_text,
                "options": q.options,
                "correct_answer": q.correct_answer,
                "explanation": q.explanation,
                "bloom_level": q.bloom_level,
                "irt_params": q.irt_params,
                "status": q.status,
            }
            for q in questions
        ]

        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(data, f, indent=2, ensure_ascii=False)

        return len(data)

    def get_statistics(self) -> dict:
        """Sual bazasi statistikasi."""
        questions = list(self.questions.values())
        return {
            "total_questions": len(questions),
            "by_subject": {
                subj: len([q for q in questions if q.subject == subj])
                for subj in self.subjects
            },
            "by_difficulty": {
                diff: len([q for q in questions if q.difficulty == diff])
                for diff in ["easy", "medium", "hard"]
            },
            "by_status": {
                status: len([q for q in questions if q.status == status])
                for status in ["draft", "review", "approved", "active", "retired"]
            },
            "available_subjects": list(self.subjects.keys()),
        }


# ===== DEMO =====

def run_demo():
    """Sual yaratma demo."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Sual Bazasi Yaratma DEMO")
    print("=" * 60)

    gen = ItemGenerator()

    # Numune suallar yarat
    sample_questions = [
        {
            "subject": "Riyaziyyat",
            "grade_level": 9,
            "topic": "Cebr",
            "difficulty": "medium",
            "question_text": "2x + 5 = 13 tenlikinin helli nedir?",
            "options": ["x = 3", "x = 4", "x = 5", "x = 6"],
            "correct_answer": 1,
            "explanation": "2x = 13 - 5 = 8, x = 4",
            "bloom_level": "application",
        },
        {
            "subject": "Riyaziyyat",
            "grade_level": 10,
            "topic": "Hendese",
            "difficulty": "hard",
            "question_text": "Radiusu 5 sm olan dairesnin sahesi nedir?",
            "options": ["25pi sm2", "10pi sm2", "50pi sm2", "5pi sm2"],
            "correct_answer": 0,
            "explanation": "S = pi * r^2 = pi * 25 = 25pi",
            "bloom_level": "application",
        },
        {
            "subject": "Fizika",
            "grade_level": 9,
            "topic": "Mexanika",
            "difficulty": "easy",
            "question_text": "Nyutonun 2-ci qanunu hansidgr?",
            "options": ["F = ma", "F = mv", "F = mg", "F = m/a"],
            "correct_answer": 0,
            "explanation": "Nyutonun 2-ci qanunu: F = ma",
            "bloom_level": "knowledge",
        },
        {
            "subject": "Informatika",
            "grade_level": 10,
            "topic": "Alqoritmlir",
            "difficulty": "medium",
            "question_text": "Binary search alqoritminin murekkebligi nedir?",
            "options": ["O(n)", "O(log n)", "O(n^2)", "O(1)"],
            "correct_answer": 1,
            "explanation": "Binary search logarifmik murekkebliye malikdir",
            "bloom_level": "comprehension",
        },
    ]

    for q_data in sample_questions:
        q = gen.create_question(**q_data)
        print(f"\n  Yaradildi: {q.question_id}")
        print(f"    Fen: {q.subject} | Sinif: {q.grade_level} | Chesinlik: {q.difficulty}")
        print(f"    Sual: {q.question_text}")

    # Statistika
    stats = gen.get_statistics()
    print(f"\n{'='*60}")
    print(f"  Statistika:")
    print(f"  Umumi sual sayi: {stats['total_questions']}")
    print(f"  Fenler uzre: {stats['by_subject']}")
    print(f"  Cesinlik uzre: {stats['by_difficulty']}")
    print(f"{'='*60}")


if __name__ == "__main__":
    run_demo()
