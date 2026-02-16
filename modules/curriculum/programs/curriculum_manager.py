"""
ARTI 2026 - Kurikulum Idareetme Sistemi
==========================================
Tedris proqramlarinin yaradilmasi, yenilenmesi ve izlenmesi.

Mehsullar:
- Fen proqramlari (ibtidai, orta, lisey, gimnaziya)
- Tedris planlari
- Standartlar ve gozlentiler
- Kontent xaritelemesi
"""

from typing import List, Dict, Optional
from dataclasses import dataclass, field
from datetime import datetime
import uuid


@dataclass
class LearningStandard:
    """Tedris standardi."""
    standard_id: str
    code: str               # Mes: "RIY.9.1.1"
    subject: str
    grade_level: int
    domain: str             # Sahə
    description: str
    bloom_level: str
    prerequisites: List[str] = field(default_factory=list)


@dataclass
class CurriculumUnit:
    """Tedris vahdeti (movzu)."""
    unit_id: str
    title: str
    description: str
    grade_level: int
    subject: str
    order: int
    duration_hours: int
    standards: List[str] = field(default_factory=list)
    topics: List[str] = field(default_factory=list)
    resources: List[str] = field(default_factory=list)


@dataclass
class CurriculumProgram:
    """Tedris proqrami."""
    program_id: str
    subject: str
    grade_level: int
    school_type: str        # umumi, lisey, gimnaziya
    academic_year: str
    total_hours: int
    units: List[CurriculumUnit] = field(default_factory=list)
    standards: List[LearningStandard] = field(default_factory=list)
    status: str = "draft"


class CurriculumManager:
    """Kurikulum idare sistemi."""

    def __init__(self):
        self.programs: Dict[str, CurriculumProgram] = {}
        self.standards: Dict[str, LearningStandard] = {}

    def create_program(self, subject: str, grade_level: int,
                       school_type: str, academic_year: str,
                       total_hours: int) -> CurriculumProgram:
        """Yeni tedris proqrami yaradir."""
        program = CurriculumProgram(
            program_id=f"PROG_{uuid.uuid4().hex[:8]}",
            subject=subject,
            grade_level=grade_level,
            school_type=school_type,
            academic_year=academic_year,
            total_hours=total_hours,
        )
        self.programs[program.program_id] = program
        return program

    def add_unit(self, program_id: str, title: str, description: str,
                 duration_hours: int, topics: List[str]) -> CurriculumUnit:
        """Proqrama tedris vahdeti elave edir."""
        program = self.programs.get(program_id)
        if not program:
            raise ValueError("Proqram tapilmadi")

        unit = CurriculumUnit(
            unit_id=f"UNIT_{uuid.uuid4().hex[:6]}",
            title=title,
            description=description,
            grade_level=program.grade_level,
            subject=program.subject,
            order=len(program.units) + 1,
            duration_hours=duration_hours,
            topics=topics,
        )
        program.units.append(unit)
        return unit

    def get_program_overview(self, program_id: str) -> dict:
        """Proqram icmali."""
        program = self.programs.get(program_id)
        if not program:
            return {"error": "Proqram tapilmadi"}

        return {
            "program_id": program.program_id,
            "subject": program.subject,
            "grade_level": program.grade_level,
            "school_type": program.school_type,
            "academic_year": program.academic_year,
            "total_hours": program.total_hours,
            "units_count": len(program.units),
            "units": [
                {
                    "order": u.order,
                    "title": u.title,
                    "hours": u.duration_hours,
                    "topics": len(u.topics),
                }
                for u in program.units
            ],
            "status": program.status,
        }


# ===== DEMO =====

def run_demo():
    """Kurikulum demo."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Kurikulum Idareetme DEMO")
    print("=" * 60)

    cm = CurriculumManager()

    # Riyaziyyat 9-cu sinif proqrami
    prog = cm.create_program("Riyaziyyat", 9, "umumi", "2026-2027", 102)

    units = [
        ("Ededler ve hesablamalar", "Rasional ve irrasional ededler", 12,
         ["Rasional ededler", "Irrasional ededler", "Heqiqi ededler", "Kokler"]),
        ("Cebri ifadeler", "Cebirde emeliyyatlar", 16,
         ["Coxhedliler", "Vuruqlara ayirma", "Kesrler", "Tenliklir"]),
        ("Tenlikler ve berabersizlikler", "Tenlik ve berabersizlik heIli", 18,
         ["Xetti tenlikler", "Kvadrat tenlikler", "Tenlik sistemleri", "Berabersizlikler"]),
        ("Funksiyalar", "Funksiya anlayishi ve novleri", 14,
         ["Funksiya anlayishi", "Xetti funksiya", "Kvadrat funksiya", "Qrafik"]),
        ("Hendese", "Mustervi hendese", 20,
         ["Uchbucaqlar", "Dordbuclaqlar", "Daire", "Sahe ve perimetr"]),
        ("Statistika ve ehtimal", "Melumat analizi", 12,
         ["Melumat toplama", "Orta deyer", "Mediana", "Ehtimal"]),
        ("Trigonometriya", "Trigonometrik funksiyalar", 10,
         ["Sin, Cos, Tan", "Trigonometrik tenliklir", "Uchbucaq heIli"]),
    ]

    for title, desc, hours, topics in units:
        cm.add_unit(prog.program_id, title, desc, hours, topics)

    overview = cm.get_program_overview(prog.program_id)
    print(f"\n  Proqram: {overview['subject']} - {overview['grade_level']}-ci sinif")
    print(f"  Mekteb tipi: {overview['school_type']}")
    print(f"  Tedris ili: {overview['academic_year']}")
    print(f"  Umumi saat: {overview['total_hours']}")
    print(f"\n  Tedris vahidleri:")
    for u in overview["units"]:
        print(f"    {u['order']}. {u['title']} ({u['hours']} saat, {u['topics']} movzu)")
    print(f"\n{'='*60}")


if __name__ == "__main__":
    run_demo()
