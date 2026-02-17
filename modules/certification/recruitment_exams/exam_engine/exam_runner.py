"""
ARTI 2026 - Muellim Ishe Qebul Imtahani Muhurriki
=====================================================
Muellim ishe qebul imtahanlarini avtomatlashdirilmish
shekilde kechiren sistem.

Funksiyalar:
- Imtahan yaratma ve planlaşdirma
- Sual bazasindan avtomatik sual secimi
- Imtahan kechirme (onlayn)
- Avtomatik qiymetlendirme
- Netice hesabati
"""

import uuid
import json
from typing import List, Dict, Optional
from dataclasses import dataclass, field
from datetime import datetime, timedelta
import random


@dataclass
class ExamQuestion:
    """Imtahan suali."""
    question_id: str
    question_text: str
    options: List[str]
    correct_answer: int
    subject: str
    difficulty: str
    points: int = 1


@dataclass
class ExamConfig:
    """Imtahan konfiqurasiyasi."""
    exam_id: str
    exam_type: str              # recruitment, certification
    title: str
    subject: str
    total_questions: int
    duration_minutes: int
    passing_score: float        # Kechid bali (faizel)
    question_distribution: Dict[str, int] = field(default_factory=dict)
    shuffle_questions: bool = True
    shuffle_options: bool = True
    show_results: bool = False  # Imtahandan sonra netice goster


@dataclass
class ExamSession:
    """Bir namizedin imtahan sessiyasi."""
    session_id: str
    exam_id: str
    candidate_id: str
    candidate_name: str
    start_time: str
    end_time: Optional[str] = None
    questions: List[ExamQuestion] = field(default_factory=list)
    answers: Dict[str, int] = field(default_factory=dict)
    score: Optional[float] = None
    status: str = "active"      # active, completed, expired, cancelled


class ExamRunner:
    """Imtahan kechirme sistemi."""

    def __init__(self):
        self.question_bank: Dict[str, List[ExamQuestion]] = {}
        self.exams: Dict[str, ExamConfig] = {}
        self.sessions: Dict[str, ExamSession] = {}

    def add_questions(self, subject: str, questions: List[dict]):
        """Sual bazasina suallar elave edir."""
        if subject not in self.question_bank:
            self.question_bank[subject] = []

        for q in questions:
            self.question_bank[subject].append(ExamQuestion(
                question_id=q.get("question_id", f"Q_{uuid.uuid4().hex[:6]}"),
                question_text=q["question_text"],
                options=q["options"],
                correct_answer=q["correct_answer"],
                subject=subject,
                difficulty=q.get("difficulty", "medium"),
                points=q.get("points", 1),
            ))

    def create_exam(self, exam_type: str, title: str, subject: str,
                    total_questions: int = 50,
                    duration_minutes: int = 90,
                    passing_score: float = 50.0,
                    distribution: Dict[str, int] = None) -> ExamConfig:
        """Yeni imtahan yaradir."""
        exam = ExamConfig(
            exam_id=f"EXAM_{uuid.uuid4().hex[:8]}",
            exam_type=exam_type,
            title=title,
            subject=subject,
            total_questions=total_questions,
            duration_minutes=duration_minutes,
            passing_score=passing_score,
            question_distribution=distribution or {
                "easy": int(total_questions * 0.3),
                "medium": int(total_questions * 0.5),
                "hard": int(total_questions * 0.2),
            },
        )
        self.exams[exam.exam_id] = exam
        return exam

    def start_exam(self, exam_id: str, candidate_id: str,
                   candidate_name: str) -> ExamSession:
        """Namized ucun imtahan bashlayir."""
        exam = self.exams.get(exam_id)
        if not exam:
            raise ValueError(f"Imtahan tapilmadi: {exam_id}")

        # Sual bazasindan sual sech
        available = self.question_bank.get(exam.subject, [])
        selected = []

        for difficulty, count in exam.question_distribution.items():
            pool = [q for q in available if q.difficulty == difficulty]
            if len(pool) >= count:
                selected.extend(random.sample(pool, count))
            else:
                selected.extend(pool)

        if exam.shuffle_questions:
            random.shuffle(selected)

        session = ExamSession(
            session_id=f"SES_{uuid.uuid4().hex[:8]}",
            exam_id=exam_id,
            candidate_id=candidate_id,
            candidate_name=candidate_name,
            start_time=datetime.now().isoformat(),
            questions=selected,
            status="active",
        )
        self.sessions[session.session_id] = session
        return session

    def submit_answer(self, session_id: str, question_id: str,
                      answer: int) -> dict:
        """Cavab gonderir."""
        session = self.sessions.get(session_id)
        if not session or session.status != "active":
            return {"error": "Sessiya aktiv deyil"}

        session.answers[question_id] = answer
        return {
            "status": "accepted",
            "question_id": question_id,
            "answered": len(session.answers),
            "total": len(session.questions),
            "remaining": len(session.questions) - len(session.answers),
        }

    def finish_exam(self, session_id: str) -> dict:
        """Imtahani bitirir ve qiymetlendirir."""
        session = self.sessions.get(session_id)
        if not session:
            return {"error": "Sessiya tapilmadi"}

        exam = self.exams[session.exam_id]
        session.end_time = datetime.now().isoformat()
        session.status = "completed"

        # Qiymetlendir
        correct = 0
        total_points = 0
        earned_points = 0
        details = []

        for q in session.questions:
            total_points += q.points
            given_answer = session.answers.get(q.question_id, -1)
            is_correct = given_answer == q.correct_answer

            if is_correct:
                correct += 1
                earned_points += q.points

            details.append({
                "question_id": q.question_id,
                "difficulty": q.difficulty,
                "given_answer": given_answer,
                "correct_answer": q.correct_answer,
                "is_correct": is_correct,
                "points": q.points if is_correct else 0,
            })

        score = (earned_points / total_points * 100) if total_points > 0 else 0
        session.score = score
        passed = score >= exam.passing_score

        return {
            "session_id": session.session_id,
            "candidate_id": session.candidate_id,
            "candidate_name": session.candidate_name,
            "exam_title": exam.title,
            "exam_type": exam.exam_type,
            "total_questions": len(session.questions),
            "answered": len(session.answers),
            "correct": correct,
            "score": round(score, 1),
            "passing_score": exam.passing_score,
            "passed": passed,
            "result": "KECHDI" if passed else "KECHMEDI",
            "duration": session.end_time,
            "by_difficulty": {
                diff: {
                    "total": len([d for d in details if d["difficulty"] == diff]),
                    "correct": len([d for d in details if d["difficulty"] == diff and d["is_correct"]]),
                }
                for diff in ["easy", "medium", "hard"]
            },
        }

    def get_exam_statistics(self, exam_id: str) -> dict:
        """Imtahan statistikasi."""
        exam_sessions = [
            s for s in self.sessions.values()
            if s.exam_id == exam_id and s.status == "completed"
        ]

        if not exam_sessions:
            return {"message": "Hele bitirmish namized yoxdur"}

        scores = [s.score for s in exam_sessions if s.score is not None]
        exam = self.exams[exam_id]

        return {
            "exam_id": exam_id,
            "exam_title": exam.title,
            "total_candidates": len(exam_sessions),
            "average_score": round(sum(scores) / len(scores), 1),
            "min_score": round(min(scores), 1),
            "max_score": round(max(scores), 1),
            "pass_rate": round(
                sum(1 for s in scores if s >= exam.passing_score) / len(scores) * 100, 1
            ),
            "score_distribution": {
                "0-20": len([s for s in scores if s < 20]),
                "20-40": len([s for s in scores if 20 <= s < 40]),
                "40-60": len([s for s in scores if 40 <= s < 60]),
                "60-80": len([s for s in scores if 60 <= s < 80]),
                "80-100": len([s for s in scores if s >= 80]),
            }
        }


# ===== DEMO =====

def run_demo():
    """Muellim ishe qebul imtahani demo."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Muellim Ishe Qebul Imtahani DEMO")
    print("=" * 60)

    runner = ExamRunner()

    # Numune sual bazasi
    math_questions = [
        {"question_text": f"Riyaziyyat suali #{i+1}",
         "options": ["A", "B", "C", "D"],
         "correct_answer": random.randint(0, 3),
         "difficulty": random.choice(["easy", "medium", "hard"]),
         "points": 2 if random.random() > 0.5 else 1}
        for i in range(100)
    ]
    runner.add_questions("Riyaziyyat", math_questions)
    print(f"\n  Sual bazasi yuklendi: {len(math_questions)} sual")

    # Imtahan yarat
    exam = runner.create_exam(
        exam_type="recruitment",
        title="2026 Riyaziyyat Muellimi Ishe Qebul Imtahani",
        subject="Riyaziyyat",
        total_questions=30,
        duration_minutes=60,
        passing_score=60.0,
        distribution={"easy": 9, "medium": 15, "hard": 6}
    )
    print(f"  Imtahan yaradildi: {exam.exam_id}")
    print(f"  Bashliq: {exam.title}")

    # 5 namized ucun simulyasiya
    candidates = [
        ("C001", "Eliyev Kamran", 0.85),
        ("C002", "Hesenova Gulnar", 0.70),
        ("C003", "Memmedov Farid", 0.55),
        ("C004", "Aliyeva Sevda", 0.40),
        ("C005", "Quliyev Rashad", 0.30),
    ]

    print(f"\n  Namizedler: {len(candidates)}")
    print("-" * 60)

    for cid, name, ability in candidates:
        session = runner.start_exam(exam.exam_id, cid, name)

        # Cavab simulyasiya
        for q in session.questions:
            # Ability ve difficulty esasinda cavab
            diff_map = {"easy": 0.7, "medium": 0.5, "hard": 0.3}
            p = ability * diff_map.get(q.difficulty, 0.5)
            answer = q.correct_answer if random.random() < p else random.randint(0, 3)
            runner.submit_answer(session.session_id, q.question_id, answer)

        result = runner.finish_exam(session.session_id)
        print(f"  {name:<20} Bal: {result['score']:5.1f}% | {result['result']}")

    # Statistika
    stats = runner.get_exam_statistics(exam.exam_id)
    print(f"\n{'='*60}")
    print(f"  IMTAHAN STATISTIKASI")
    print(f"  Namized sayi:  {stats['total_candidates']}")
    print(f"  Orta bal:      {stats['average_score']}%")
    print(f"  Min/Max:       {stats['min_score']}% / {stats['max_score']}%")
    print(f"  Kechid faizi:  {stats['pass_rate']}%")
    print(f"  Bal paylanmasi: {stats['score_distribution']}")
    print(f"{'='*60}")


if __name__ == "__main__":
    run_demo()
