"""
ARTI 2026 - Mekteb Analitikasi
================================
Mekteb seviyyesinde test neticelerinin analizi.
"""

import numpy as np
from typing import List, Dict, Optional
from dataclasses import dataclass


@dataclass
class SchoolStats:
    """Bir mektebin statistikasi."""
    school_id: str
    school_name: str
    school_type: str  # "lisey", "gimnaziya", "umumi"
    region: str
    student_count: int
    avg_theta: float
    avg_score: float
    std_dev: float
    pass_rate: float
    by_subject: Dict[str, dict]


class SchoolAnalytics:
    """Mekteb analitika sistemi."""

    def __init__(self):
        self.schools: Dict[str, SchoolStats] = {}

    def analyze_school(self, school_id: str, results: List[dict]) -> SchoolStats:
        """Bir mektebin neticelerini analiz edir."""
        if not results:
            return None

        scores = [r["percentage"] for r in results]
        thetas = [r["theta"] for r in results if r.get("theta") is not None]

        by_subject = {}
        for r in results:
            subj = r["subject"]
            if subj not in by_subject:
                by_subject[subj] = {"scores": [], "count": 0}
            by_subject[subj]["scores"].append(r["percentage"])
            by_subject[subj]["count"] += 1

        for subj in by_subject:
            s = by_subject[subj]["scores"]
            by_subject[subj] = {
                "count": len(s),
                "average": round(np.mean(s), 1),
                "std_dev": round(np.std(s), 1),
                "min": round(min(s), 1),
                "max": round(max(s), 1),
            }

        stats = SchoolStats(
            school_id=school_id,
            school_name=results[0].get("school_name", ""),
            school_type=results[0].get("school_type", "umumi"),
            region=results[0].get("region", ""),
            student_count=len(results),
            avg_theta=round(np.mean(thetas), 3) if thetas else 0.0,
            avg_score=round(np.mean(scores), 1),
            std_dev=round(np.std(scores), 1),
            pass_rate=round(sum(1 for s in scores if s >= 50) / len(scores) * 100, 1),
            by_subject=by_subject,
        )

        self.schools[school_id] = stats
        return stats

    def compare_schools(self, school_ids: List[str] = None) -> List[dict]:
        """Mektebləri muqayise edir."""
        schools = self.schools.values()
        if school_ids:
            schools = [s for s in schools if s.school_id in school_ids]

        return sorted(
            [
                {
                    "school_id": s.school_id,
                    "school_name": s.school_name,
                    "type": s.school_type,
                    "students": s.student_count,
                    "avg_score": s.avg_score,
                    "pass_rate": s.pass_rate,
                }
                for s in schools
            ],
            key=lambda x: x["avg_score"],
            reverse=True
        )

    def regional_report(self) -> Dict[str, dict]:
        """Bolge uzre hesabat."""
        regions = {}
        for s in self.schools.values():
            if s.region not in regions:
                regions[s.region] = {"schools": 0, "scores": [], "students": 0}
            regions[s.region]["schools"] += 1
            regions[s.region]["scores"].append(s.avg_score)
            regions[s.region]["students"] += s.student_count

        for region in regions:
            r = regions[region]
            r["average"] = round(np.mean(r["scores"]), 1)
            del r["scores"]

        return regions
