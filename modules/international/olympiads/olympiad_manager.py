"""
ARTI 2026 - Olimpiada ve Beynelxalq Proqramlar
=================================================
Olimpiadalar, STEAM, mubadile proqramlari.
"""

from typing import List, Dict, Optional
from dataclasses import dataclass, field
import uuid


@dataclass
class Olympiad:
    """Olimpiada."""
    olympiad_id: str
    title: str
    subject: str
    level: str          # school, regional, national, international
    academic_year: str
    stages: List[str] = field(default_factory=list)
    participants_count: int = 0
    results: List[dict] = field(default_factory=list)


@dataclass
class STEAMProject:
    """STEAM layihesi."""
    project_id: str
    title: str
    description: str
    domains: List[str]  # Science, Technology, Engineering, Art, Math
    target_grades: List[int]
    participating_schools: List[str] = field(default_factory=list)
    status: str = "planning"


class InternationalManager:
    """Beynelxalq proqramlar idarechisi."""

    def __init__(self):
        self.olympiads: Dict[str, Olympiad] = {}
        self.steam_projects: Dict[str, STEAMProject] = {}

    def create_olympiad(self, title: str, subject: str,
                        level: str, academic_year: str) -> Olympiad:
        olympiad = Olympiad(
            olympiad_id=f"OLY_{uuid.uuid4().hex[:8]}",
            title=title,
            subject=subject,
            level=level,
            academic_year=academic_year,
            stages=["Mekteb merhele", "Rayon merhele", "Respublika merhele"]
            if level == "national" else ["Mekteb merhele"],
        )
        self.olympiads[olympiad.olympiad_id] = olympiad
        return olympiad

    def create_steam_project(self, title: str, description: str,
                             domains: List[str],
                             target_grades: List[int]) -> STEAMProject:
        project = STEAMProject(
            project_id=f"STEAM_{uuid.uuid4().hex[:8]}",
            title=title,
            description=description,
            domains=domains,
            target_grades=target_grades,
        )
        self.steam_projects[project.project_id] = project
        return project


# ===== DEMO =====

def run_demo():
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Olimpiada ve STEAM DEMO")
    print("=" * 60)

    mgr = InternationalManager()

    # Olimpiadalar
    olympiads_data = [
        ("Riyaziyyat Olimpiadasi 2026", "Riyaziyyat", "national", "2025-2026"),
        ("Fizika Olimpiadasi 2026", "Fizika", "national", "2025-2026"),
        ("Informatika Olimpiadasi 2026", "Informatika", "national", "2025-2026"),
        ("Beynalxalq Riyaziyyat Olimpiadasi", "Riyaziyyat", "international", "2025-2026"),
    ]

    for title, subj, level, year in olympiads_data:
        o = mgr.create_olympiad(title, subj, level, year)
        print(f"\n  Olimpiada: {o.title}")
        print(f"    Seviyye: {o.level} | Merheleler: {len(o.stages)}")

    # STEAM layiheleri
    steam_data = [
        ("Robotika ve AI", "Robotların proqramlasdirılması",
         ["Technology", "Engineering", "Math"], [8, 9, 10]),
        ("Ekoloji Monitorinq", "Heyet ve mekteb etrafi ekosistem tedqiqati",
         ["Science", "Technology", "Art"], [7, 8, 9]),
    ]

    for title, desc, domains, grades in steam_data:
        p = mgr.create_steam_project(title, desc, domains, grades)
        print(f"\n  STEAM: {p.title}")
        print(f"    Saheler: {', '.join(p.domains)}")

    print(f"\n{'='*60}")


if __name__ == "__main__":
    run_demo()
