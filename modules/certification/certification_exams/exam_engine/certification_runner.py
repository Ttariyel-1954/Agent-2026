"""
ARTI 2026 - Muellim Sertifikasiya Imtahani
==============================================
Muellim sertifikasiya prosesini avtomatlasdirir.

Sertifikasiya merheleri:
1. Ibtidai qiymetlendirme (screening)
2. Fen bilikleri imtahani
3. Pedaqoji bacariqlar imtahani
4. Praktiki imtahan (demo ders)
5. Yekun qiymetlendirme
"""

from typing import List, Dict, Optional
from dataclasses import dataclass, field
from datetime import datetime
import uuid


@dataclass
class CertificationStage:
    """Sertifikasiya merhelesi."""
    stage_id: str
    stage_name: str
    stage_number: int
    weight: float              # Yekun balda cekisi (0-1)
    passing_score: float       # Kechid bali
    max_score: float = 100.0


@dataclass
class CandidateProfile:
    """Namized profili."""
    candidate_id: str
    full_name: str
    subject: str
    current_school: str
    experience_years: int
    qualification: str
    stages_completed: Dict[str, dict] = field(default_factory=dict)
    final_score: Optional[float] = None
    certification_status: str = "pending"  # pending, in_progress, passed, failed


class CertificationSystem:
    """Sertifikasiya sistemi."""

    # Standart sertifikasiya merheleri
    DEFAULT_STAGES = [
        CertificationStage("S1", "Ibtidai Qiymetlendirme", 1, 0.10, 60.0),
        CertificationStage("S2", "Fen Bilikleri", 2, 0.30, 50.0),
        CertificationStage("S3", "Pedaqoji Bacariqlar", 3, 0.25, 50.0),
        CertificationStage("S4", "Praktiki Imtahan", 4, 0.20, 60.0),
        CertificationStage("S5", "Yekun Qiymetlendirme", 5, 0.15, 50.0),
    ]

    def __init__(self):
        self.stages = {s.stage_id: s for s in self.DEFAULT_STAGES}
        self.candidates: Dict[str, CandidateProfile] = {}

    def register_candidate(self, full_name: str, subject: str,
                           current_school: str, experience_years: int,
                           qualification: str) -> CandidateProfile:
        """Namized qeydiyyati."""
        candidate = CandidateProfile(
            candidate_id=f"CERT_{uuid.uuid4().hex[:8]}",
            full_name=full_name,
            subject=subject,
            current_school=current_school,
            experience_years=experience_years,
            qualification=qualification,
            certification_status="in_progress",
        )
        self.candidates[candidate.candidate_id] = candidate
        return candidate

    def submit_stage_result(self, candidate_id: str, stage_id: str,
                            score: float) -> dict:
        """Merhele neticesi gondermek."""
        candidate = self.candidates.get(candidate_id)
        if not candidate:
            return {"error": "Namized tapilmadi"}

        stage = self.stages.get(stage_id)
        if not stage:
            return {"error": "Merhele tapilmadi"}

        passed = score >= stage.passing_score
        candidate.stages_completed[stage_id] = {
            "stage_name": stage.stage_name,
            "score": score,
            "max_score": stage.max_score,
            "passing_score": stage.passing_score,
            "passed": passed,
            "date": datetime.now().isoformat(),
        }

        return {
            "candidate": candidate.full_name,
            "stage": stage.stage_name,
            "score": score,
            "passed": passed,
            "message": "Kechdi" if passed else "Kechmedi",
        }

    def calculate_final_result(self, candidate_id: str) -> dict:
        """Yekun neticeni hesabla."""
        candidate = self.candidates.get(candidate_id)
        if not candidate:
            return {"error": "Namized tapilmadi"}

        weighted_score = 0
        all_passed = True

        for stage_id, stage in self.stages.items():
            result = candidate.stages_completed.get(stage_id)
            if not result:
                return {
                    "status": "incomplete",
                    "message": f"{stage.stage_name} merhelesi tamamlanmayib"
                }

            weighted_score += result["score"] * stage.weight
            if not result["passed"]:
                all_passed = False

        candidate.final_score = round(weighted_score, 1)
        candidate.certification_status = "passed" if all_passed else "failed"

        return {
            "candidate_id": candidate.candidate_id,
            "full_name": candidate.full_name,
            "subject": candidate.subject,
            "final_score": candidate.final_score,
            "all_stages_passed": all_passed,
            "certification_status": candidate.certification_status,
            "stages_detail": candidate.stages_completed,
            "certificate_number": f"ARTI-{datetime.now().year}-{uuid.uuid4().hex[:6].upper()}"
            if all_passed else None,
        }


# ===== DEMO =====

def run_demo():
    """Sertifikasiya demo."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Muellim Sertifikasiya Sistemi DEMO")
    print("=" * 60)

    system = CertificationSystem()

    # Namized qeydiyyati
    candidate = system.register_candidate(
        full_name="Hesenova Aynur",
        subject="Riyaziyyat",
        current_school="Baki sheheri 45 nomreli mekteb",
        experience_years=8,
        qualification="Bakalavr",
    )

    print(f"\n  Namized: {candidate.full_name}")
    print(f"  Fen: {candidate.subject}")
    print(f"  Tecrube: {candidate.experience_years} il")
    print("-" * 60)

    # Merheleler
    stage_scores = [
        ("S1", 75.0),
        ("S2", 82.0),
        ("S3", 68.0),
        ("S4", 71.0),
        ("S5", 88.0),
    ]

    for stage_id, score in stage_scores:
        result = system.submit_stage_result(candidate.candidate_id, stage_id, score)
        status = "KECHDI" if result["passed"] else "KECHMEDI"
        print(f"  {result['stage']:<30} Bal: {score:5.1f} | {status}")

    # Yekun
    final = system.calculate_final_result(candidate.candidate_id)
    print(f"\n{'='*60}")
    print(f"  YEKUN NETICE")
    print(f"  Namized:       {final['full_name']}")
    print(f"  Yekun bal:     {final['final_score']}")
    print(f"  Status:        {final['certification_status'].upper()}")
    if final.get("certificate_number"):
        print(f"  Sertifikat #:  {final['certificate_number']}")
    print(f"{'='*60}")


if __name__ == "__main__":
    run_demo()
