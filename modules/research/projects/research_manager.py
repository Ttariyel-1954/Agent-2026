"""
ARTI 2026 - Tedqiqat Layihe Idareetmesi
==========================================
Elmi-pedaqoji tedqiqat layihelerinin idare edilmesi.

Tedqiqat saheleri:
- Tahsil siyaseti tedqiqatlari
- Pedaqoji innovasiyalar
- Qiymetlendirme metodologiyasi
- Muellim peshkarligi
- Inkluziv tahsil
- STEAM tahsili
"""

from typing import List, Dict, Optional
from dataclasses import dataclass, field
from datetime import datetime, date
import uuid


@dataclass
class Researcher:
    """Tedqiqatchi."""
    researcher_id: str
    full_name: str
    title: str          # PhD, DocSci, Professor
    department: str
    specialization: str
    publications_count: int = 0


@dataclass
class ResearchProject:
    """Tedqiqat layihesi."""
    project_id: str
    title: str
    description: str
    research_area: str
    methodology: str
    lead_researcher: str
    team: List[str] = field(default_factory=list)
    status: str = "proposal"  # proposal, approved, active, completed, published
    start_date: Optional[str] = None
    end_date: Optional[str] = None
    budget: float = 0.0
    deliverables: List[str] = field(default_factory=list)
    publications: List[str] = field(default_factory=list)
    keywords: List[str] = field(default_factory=list)


@dataclass
class Publication:
    """Neshr."""
    publication_id: str
    title: str
    authors: List[str]
    pub_type: str       # journal, conference, report, book
    journal: Optional[str] = None
    abstract: str = ""
    doi: Optional[str] = None
    published_date: Optional[str] = None
    project_id: Optional[str] = None


class ResearchManager:
    """Tedqiqat idare sistemi."""

    def __init__(self):
        self.projects: Dict[str, ResearchProject] = {}
        self.publications: Dict[str, Publication] = {}
        self.researchers: Dict[str, Researcher] = {}

    def create_project(self, title: str, description: str,
                       research_area: str, methodology: str,
                       lead_researcher: str,
                       keywords: List[str] = None) -> ResearchProject:
        """Yeni tedqiqat layihesi yaradir."""
        project = ResearchProject(
            project_id=f"RP_{uuid.uuid4().hex[:8]}",
            title=title,
            description=description,
            research_area=research_area,
            methodology=methodology,
            lead_researcher=lead_researcher,
            keywords=keywords or [],
        )
        self.projects[project.project_id] = project
        return project

    def add_publication(self, title: str, authors: List[str],
                        pub_type: str, project_id: str = None,
                        **kwargs) -> Publication:
        """Neshr elave edir."""
        pub = Publication(
            publication_id=f"PUB_{uuid.uuid4().hex[:8]}",
            title=title,
            authors=authors,
            pub_type=pub_type,
            project_id=project_id,
            **kwargs,
        )
        self.publications[pub.publication_id] = pub
        return pub

    def get_statistics(self) -> dict:
        """Tedqiqat statistikasi."""
        return {
            "total_projects": len(self.projects),
            "by_status": {
                status: len([p for p in self.projects.values() if p.status == status])
                for status in ["proposal", "approved", "active", "completed", "published"]
            },
            "total_publications": len(self.publications),
            "by_type": {
                t: len([p for p in self.publications.values() if p.pub_type == t])
                for t in ["journal", "conference", "report", "book"]
            },
            "total_researchers": len(self.researchers),
        }


# ===== DEMO =====

def run_demo():
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Tedqiqat Idare Sistemi DEMO")
    print("=" * 60)

    rm = ResearchManager()

    projects = [
        ("CAT Testlerin Azerbaycan Tahsilinde Tetbiqi",
         "Komputer adaptiv testlerin milli seviyyede tetbiqi tedqiqati",
         "Qiymetlendirme", "Eksperimental", "Dr. Aliyev T.",
         ["CAT", "IRT", "adaptiv test"]),
        ("Muellim Peshkarliginin Olculmesi",
         "Sertifikasiya sisteminin effektivliyi",
         "Muellim peshkarligi", "Survey", "Prof. Hesenov M.",
         ["sertifikasiya", "peshkarlig", "qiymetlendirme"]),
        ("STEAM Tahsilinin Shagird Nailiyyetlerine Tesiri",
         "STEAM metodologiyasinin tatbiqi neticeleri",
         "STEAM", "Qarışiq metod", "Dr. Memmedova S.",
         ["STEAM", "nailiyyet", "innovasiya"]),
    ]

    for title, desc, area, method, lead, kw in projects:
        p = rm.create_project(title, desc, area, method, lead, kw)
        p.status = "active"
        print(f"\n  Layihe: {p.title[:50]}...")
        print(f"    Sahe: {p.research_area} | Rehber: {p.lead_researcher}")

    stats = rm.get_statistics()
    print(f"\n  Umumi layihe: {stats['total_projects']}")
    print("=" * 60)


if __name__ == "__main__":
    run_demo()
