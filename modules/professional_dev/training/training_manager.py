"""
ARTI 2026 - Peshkar Inkishaf / Telim Idareetmesi
===================================================
Muellim telimleri, kurslar ve mentorluq proqramlari.

Telim novleri:
- Uzuzlu telimler
- Onlayn kurslar
- Qarışiq (blended) telimler
- Mentorluq proqramlari
"""

from typing import List, Dict, Optional
from dataclasses import dataclass, field
import uuid


@dataclass
class TrainingProgram:
    """Telim proqrami."""
    program_id: str
    title: str
    description: str
    program_type: str   # online, face_to_face, blended
    subject_area: str
    target_audience: str  # primary_teacher, secondary_teacher, school_admin
    duration_hours: int
    max_participants: int
    modules: List[dict] = field(default_factory=list)
    status: str = "draft"


@dataclass
class Enrollment:
    """Telime qeydiyyat."""
    enrollment_id: str
    program_id: str
    teacher_id: str
    teacher_name: str
    pre_score: Optional[float] = None
    post_score: Optional[float] = None
    attendance: float = 0.0
    status: str = "enrolled"  # enrolled, in_progress, completed, dropped


class TrainingManager:
    """Telim idare sistemi."""

    def __init__(self):
        self.programs: Dict[str, TrainingProgram] = {}
        self.enrollments: Dict[str, Enrollment] = {}

    def create_program(self, title: str, program_type: str,
                       subject_area: str, duration_hours: int,
                       max_participants: int = 30,
                       target_audience: str = "secondary_teacher") -> TrainingProgram:
        """Yeni telim proqrami yaradir."""
        program = TrainingProgram(
            program_id=f"TP_{uuid.uuid4().hex[:8]}",
            title=title,
            description="",
            program_type=program_type,
            subject_area=subject_area,
            target_audience=target_audience,
            duration_hours=duration_hours,
            max_participants=max_participants,
        )
        self.programs[program.program_id] = program
        return program

    def enroll_teacher(self, program_id: str, teacher_id: str,
                       teacher_name: str) -> Enrollment:
        """Muellimi telime qeydiyyata alir."""
        enrollment = Enrollment(
            enrollment_id=f"EN_{uuid.uuid4().hex[:6]}",
            program_id=program_id,
            teacher_id=teacher_id,
            teacher_name=teacher_name,
        )
        self.enrollments[enrollment.enrollment_id] = enrollment
        return enrollment

    def complete_training(self, enrollment_id: str,
                          post_score: float, attendance: float) -> dict:
        """Telimi tamamlayir."""
        enrollment = self.enrollments.get(enrollment_id)
        if not enrollment:
            return {"error": "Qeydiyyat tapilmadi"}

        enrollment.post_score = post_score
        enrollment.attendance = attendance
        enrollment.status = "completed" if attendance >= 80 else "dropped"

        improvement = None
        if enrollment.pre_score and enrollment.post_score:
            improvement = enrollment.post_score - enrollment.pre_score

        return {
            "teacher": enrollment.teacher_name,
            "status": enrollment.status,
            "post_score": post_score,
            "attendance": attendance,
            "improvement": improvement,
        }

    def get_training_effectiveness(self, program_id: str) -> dict:
        """Telim effektivliyi analizi."""
        enrollments = [
            e for e in self.enrollments.values()
            if e.program_id == program_id and e.status == "completed"
        ]

        if not enrollments:
            return {"message": "Melumat yoxdur"}

        pre_scores = [e.pre_score for e in enrollments if e.pre_score]
        post_scores = [e.post_score for e in enrollments if e.post_score]

        return {
            "program_id": program_id,
            "completed": len(enrollments),
            "avg_pre_score": round(sum(pre_scores) / len(pre_scores), 1) if pre_scores else None,
            "avg_post_score": round(sum(post_scores) / len(post_scores), 1) if post_scores else None,
            "avg_improvement": round(
                (sum(post_scores) / len(post_scores)) - (sum(pre_scores) / len(pre_scores)), 1
            ) if pre_scores and post_scores else None,
        }


# ===== DEMO =====

def run_demo():
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Muellim Telim Sistemi DEMO")
    print("=" * 60)

    tm = TrainingManager()

    programs = [
        ("CAT/MST Test Texnologiyalari Telimi", "blended", "Qiymetlendirme", 40),
        ("Raqamsal Savadliq Kursu", "online", "Texnologiya", 24),
        ("Inkluziv Tahsil Seminar", "face_to_face", "Pedaqogika", 16),
        ("STEAM Metodologiyasi Telimi", "blended", "STEAM", 32),
    ]

    for title, ptype, area, hours in programs:
        p = tm.create_program(title, ptype, area, hours)
        print(f"\n  Telim: {p.title}")
        print(f"    Nov: {p.program_type} | Saat: {p.duration_hours}")

    print(f"\n  Umumi telim proqrami: {len(tm.programs)}")
    print("=" * 60)


if __name__ == "__main__":
    run_demo()
