"""
ARTI 2026 - Mekteb Shebekesi Melumat Toplama
===============================================
Lisey ve gimnaziyalardan melumat toplama sistemi.

Toplanan melumatlar:
- Shagird demografik melumatlari
- Test neticeleri (CAT/MST)
- Muellim melumatlari
- Mekteb infrastrukturu
- Tedris prosesinisi izleme
"""

from typing import List, Dict, Optional
from dataclasses import dataclass, field
from datetime import datetime
import uuid


@dataclass
class SchoolProfile:
    """Mekteb profili."""
    school_id: str
    school_name: str
    school_type: str     # lisey, gimnaziya, umumi
    region: str
    district: str
    address: str
    director: str
    phone: str
    email: str
    student_count: int
    teacher_count: int
    class_count: int
    founded_year: int
    has_computer_lab: bool = False
    internet_speed: str = ""
    last_update: str = ""


@dataclass
class DataCollectionForm:
    """Melumat toplama formasi."""
    form_id: str
    school_id: str
    form_type: str       # student_data, test_results, teacher_data, infrastructure
    data: Dict = field(default_factory=dict)
    submitted_by: str = ""
    submitted_at: str = ""
    status: str = "pending"  # pending, verified, rejected


class SchoolDataCollector:
    """Mekteb melumat toplama sistemi."""

    def __init__(self):
        self.schools: Dict[str, SchoolProfile] = {}
        self.forms: Dict[str, DataCollectionForm] = {}

    def register_school(self, **kwargs) -> SchoolProfile:
        """Mekteb qeydiyyati."""
        school = SchoolProfile(
            school_id=f"SCH_{uuid.uuid4().hex[:8]}",
            last_update=datetime.now().isoformat(),
            **kwargs,
        )
        self.schools[school.school_id] = school
        return school

    def submit_form(self, school_id: str, form_type: str,
                    data: dict, submitted_by: str) -> DataCollectionForm:
        """Melumat formasi gondermek."""
        form = DataCollectionForm(
            form_id=f"FORM_{uuid.uuid4().hex[:8]}",
            school_id=school_id,
            form_type=form_type,
            data=data,
            submitted_by=submitted_by,
            submitted_at=datetime.now().isoformat(),
        )
        self.forms[form.form_id] = form
        return form

    def get_collection_status(self) -> dict:
        """Melumat toplama statusu."""
        return {
            "registered_schools": len(self.schools),
            "submitted_forms": len(self.forms),
            "by_type": {
                "lisey": len([s for s in self.schools.values() if s.school_type == "lisey"]),
                "gimnaziya": len([s for s in self.schools.values() if s.school_type == "gimnaziya"]),
                "umumi": len([s for s in self.schools.values() if s.school_type == "umumi"]),
            },
            "forms_by_status": {
                "pending": len([f for f in self.forms.values() if f.status == "pending"]),
                "verified": len([f for f in self.forms.values() if f.status == "verified"]),
                "rejected": len([f for f in self.forms.values() if f.status == "rejected"]),
            },
        }

    def get_network_overview(self) -> dict:
        """Mekteb shebekesinin umumi goruntusi."""
        schools = list(self.schools.values())
        if not schools:
            return {"message": "Hele mekteb qeydiyyati yoxdur"}

        total_students = sum(s.student_count for s in schools)
        total_teachers = sum(s.teacher_count for s in schools)

        by_region = {}
        for s in schools:
            if s.region not in by_region:
                by_region[s.region] = {"count": 0, "students": 0}
            by_region[s.region]["count"] += 1
            by_region[s.region]["students"] += s.student_count

        return {
            "total_schools": len(schools),
            "total_students": total_students,
            "total_teachers": total_teachers,
            "by_region": by_region,
            "computer_lab_coverage": round(
                sum(1 for s in schools if s.has_computer_lab) / len(schools) * 100, 1
            ),
        }


# ===== DEMO =====

def run_demo():
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Mekteb Shebekesi Melumat Toplama DEMO")
    print("=" * 60)

    collector = SchoolDataCollector()

    # Numune mektebler
    schools_data = [
        {"school_name": "Baki sheheri 6 nomreli lisey", "school_type": "lisey",
         "region": "Baki", "district": "Nesimi", "address": "28 May kuc.",
         "director": "Eliyev R.", "phone": "+994501234567", "email": "lisey6@edu.az",
         "student_count": 450, "teacher_count": 45, "class_count": 18,
         "founded_year": 1998, "has_computer_lab": True, "internet_speed": "100 Mbps"},

        {"school_name": "Gence sheheri 2 nomreli gimnaziya", "school_type": "gimnaziya",
         "region": "Gence", "district": "Merkez", "address": "Ataturk pr.",
         "director": "Hesenov A.", "phone": "+994551234567", "email": "gimn2@edu.az",
         "student_count": 380, "teacher_count": 38, "class_count": 15,
         "founded_year": 2005, "has_computer_lab": True, "internet_speed": "50 Mbps"},

        {"school_name": "Sumqayit sheheri 15 nomreli mekteb", "school_type": "umumi",
         "region": "Sumqayit", "district": "Merkez", "address": "Semed Vurgun kuc.",
         "director": "Quliyeva N.", "phone": "+994701234567", "email": "mek15@edu.az",
         "student_count": 620, "teacher_count": 52, "class_count": 24,
         "founded_year": 1985, "has_computer_lab": False, "internet_speed": "10 Mbps"},
    ]

    for data in schools_data:
        school = collector.register_school(**data)
        print(f"\n  {school.school_name}")
        print(f"    Tip: {school.school_type} | Region: {school.region}")
        print(f"    Shagird: {school.student_count} | Muellim: {school.teacher_count}")

    overview = collector.get_network_overview()
    print(f"\n{'='*60}")
    print(f"  Shebekə Icmali:")
    print(f"  Mekteb sayi:     {overview['total_schools']}")
    print(f"  Shagird sayi:    {overview['total_students']}")
    print(f"  Muellim sayi:    {overview['total_teachers']}")
    print(f"  Komp. lab:       {overview['computer_lab_coverage']}%")
    print(f"{'='*60}")


if __name__ == "__main__":
    run_demo()
