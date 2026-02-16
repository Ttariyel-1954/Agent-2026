"""
ARTI 2026 - Numune Melumat Yukleme Skripti
=============================================
Verilener bazasina numune melumatlar yukleyir.
python scripts/data_tools/seed_database.py
"""

import json
import os
import random
import uuid


def generate_schools(count=20):
    """Numune mekteb melumatlari."""
    regions = ["Baki", "Gence", "Sumqayit", "Mingechevir", "Sheki",
               "Lenkeran", "Naxchivan", "Shirvan", "Quba", "Shamakhi"]
    types = ["lisey", "gimnaziya", "umumi"]

    schools = []
    for i in range(count):
        region = random.choice(regions)
        school_type = random.choice(types)
        schools.append({
            "school_id": str(uuid.uuid4()),
            "school_name": f"{region} {school_type.capitalize()} #{i+1}",
            "school_type": school_type,
            "region": region,
            "student_count": random.randint(200, 800),
            "teacher_count": random.randint(20, 60),
        })
    return schools


def generate_students(schools, per_school=30):
    """Numune shagird melumatlari."""
    first_names = ["Ali", "Veli", "Aysel", "Fidan", "Kamran", "Gulnar",
                   "Rashad", "Sevda", "Farid", "Nigar", "Tural", "Leyla"]
    last_names = ["Aliyev", "Hesenov", "Memmedov", "Quliyev", "Huseynov",
                  "Babayev", "Rehimov", "Ismayilov", "Kerimov", "Novruzov"]

    students = []
    for school in schools:
        for _ in range(per_school):
            first = random.choice(first_names)
            last = random.choice(last_names)
            gender = "M" if first in ["Ali", "Veli", "Kamran", "Rashad", "Farid", "Tural"] else "F"
            students.append({
                "student_id": str(uuid.uuid4()),
                "school_id": school["school_id"],
                "full_name": f"{last} {first}",
                "grade_level": random.randint(5, 11),
                "gender": gender,
            })
    return students


def generate_teachers(schools, per_school=5):
    """Numune muellim melumatlari."""
    subjects = ["Riyaziyyat", "Fizika", "Kimya", "Biologiya", "Informatika",
                "Azerbaycan dili", "Tarix", "Cografiya", "Ingilis dili"]

    teachers = []
    for school in schools:
        for _ in range(per_school):
            teachers.append({
                "teacher_id": str(uuid.uuid4()),
                "school_id": school["school_id"],
                "subject": random.choice(subjects),
                "experience_years": random.randint(1, 30),
                "qualification": random.choice(["Bakalavr", "Magistr", "Doktor"]),
            })
    return teachers


def main():
    print("=" * 50)
    print("  ARTI 2026 - Numune Melumat Yaradilir...")
    print("=" * 50)

    base_dir = os.path.join(os.path.dirname(__file__), "..", "..", "data", "sample")
    os.makedirs(base_dir, exist_ok=True)

    # Mektebler
    schools = generate_schools(20)
    with open(os.path.join(base_dir, "schools", "schools.json"), "w", encoding="utf-8") as f:
        json.dump(schools, f, indent=2, ensure_ascii=False)
    print(f"  Mektebler: {len(schools)}")

    # Shagirdler
    students = generate_students(schools, 30)
    with open(os.path.join(base_dir, "students", "students.json"), "w", encoding="utf-8") as f:
        json.dump(students, f, indent=2, ensure_ascii=False)
    print(f"  Shagirdler: {len(students)}")

    # Muellemler
    teachers = generate_teachers(schools, 5)
    with open(os.path.join(base_dir, "teachers", "teachers.json"), "w", encoding="utf-8") as f:
        json.dump(teachers, f, indent=2, ensure_ascii=False)
    print(f"  Muellemler: {len(teachers)}")

    print(f"\n  Melumatlar {base_dir} qovlugunda saxlandi.")
    print("=" * 50)


if __name__ == "__main__":
    main()
