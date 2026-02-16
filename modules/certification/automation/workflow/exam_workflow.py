"""
ARTI 2026 - Imtahan Avtomatlasdirma İş Axını
================================================
Imtahan prosesinin bashdansonacen avtomatlasdirilmasi.

Is axini:
1. Imtahan planlasdirma
2. Sual secimi ve test formasinin yaradilmasi
3. Namized qeydiyyati
4. Imtahan kechirme
5. Avtomatik qiymetlendirme
6. Netice bildirishi
7. Hesabat yaratma
"""

from enum import Enum
from typing import List, Dict, Optional, Callable
from dataclasses import dataclass, field
from datetime import datetime
import uuid


class WorkflowStatus(Enum):
    PENDING = "pending"
    IN_PROGRESS = "in_progress"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


@dataclass
class WorkflowStep:
    """Is axini addimi."""
    step_id: str
    name: str
    order: int
    status: WorkflowStatus = WorkflowStatus.PENDING
    result: Optional[dict] = None
    started_at: Optional[str] = None
    completed_at: Optional[str] = None
    error: Optional[str] = None


@dataclass
class ExamWorkflow:
    """Imtahan is axini."""
    workflow_id: str
    exam_type: str
    title: str
    created_at: str
    steps: List[WorkflowStep] = field(default_factory=list)
    current_step: int = 0
    status: WorkflowStatus = WorkflowStatus.PENDING
    metadata: Dict = field(default_factory=dict)


class WorkflowEngine:
    """Imtahan is axini muhurriki."""

    def __init__(self):
        self.workflows: Dict[str, ExamWorkflow] = {}

    def create_recruitment_workflow(self, title: str) -> ExamWorkflow:
        """Ishe qebul imtahani is axini yaradir."""
        workflow = ExamWorkflow(
            workflow_id=f"WF_{uuid.uuid4().hex[:8]}",
            exam_type="recruitment",
            title=title,
            created_at=datetime.now().isoformat(),
            steps=[
                WorkflowStep("S1", "Imtahan planlasdirma", 1),
                WorkflowStep("S2", "Sual bazasindan sual secimi", 2),
                WorkflowStep("S3", "Test formasinin yaradilmasi", 3),
                WorkflowStep("S4", "Namized qeydiyyati", 4),
                WorkflowStep("S5", "Imtahan otaqlari/serverler hazirligi", 5),
                WorkflowStep("S6", "Imtahanin kechirilmesi", 6),
                WorkflowStep("S7", "Avtomatik qiymetlendirme", 7),
                WorkflowStep("S8", "Netice yoxlamasi (QA)", 8),
                WorkflowStep("S9", "Neticelerin elani", 9),
                WorkflowStep("S10", "Yekun hesabat", 10),
            ]
        )
        self.workflows[workflow.workflow_id] = workflow
        return workflow

    def create_certification_workflow(self, title: str) -> ExamWorkflow:
        """Sertifikasiya imtahani is axini yaradir."""
        workflow = ExamWorkflow(
            workflow_id=f"WF_{uuid.uuid4().hex[:8]}",
            exam_type="certification",
            title=title,
            created_at=datetime.now().isoformat(),
            steps=[
                WorkflowStep("S1", "Sertifikasiya dovresi planlasdirma", 1),
                WorkflowStep("S2", "Namized qeydiyyati ve sened yoxlamasi", 2),
                WorkflowStep("S3", "Ibtidai qiymetlendirme hazirligi", 3),
                WorkflowStep("S4", "Ibtidai qiymetlendirme kechirme", 4),
                WorkflowStep("S5", "Fen bilikleri imtahani hazirligi", 5),
                WorkflowStep("S6", "Fen bilikleri imtahani kechirme", 6),
                WorkflowStep("S7", "Pedaqoji bacariqlar imtahani", 7),
                WorkflowStep("S8", "Praktiki imtahan (demo ders)", 8),
                WorkflowStep("S9", "Yekun qiymetlendirme", 9),
                WorkflowStep("S10", "Sertifikat vermə", 10),
                WorkflowStep("S11", "Yekun hesabat ve arxivleme", 11),
            ]
        )
        self.workflows[workflow.workflow_id] = workflow
        return workflow

    def advance_step(self, workflow_id: str,
                     result: dict = None) -> dict:
        """Novbeti addima kech."""
        wf = self.workflows.get(workflow_id)
        if not wf:
            return {"error": "Workflow tapilmadi"}

        if wf.current_step >= len(wf.steps):
            return {"status": "already_completed"}

        # Cari addimi tamamla
        current = wf.steps[wf.current_step]
        current.status = WorkflowStatus.COMPLETED
        current.completed_at = datetime.now().isoformat()
        current.result = result

        wf.current_step += 1

        # Son addim idise
        if wf.current_step >= len(wf.steps):
            wf.status = WorkflowStatus.COMPLETED
            return {
                "workflow_id": wf.workflow_id,
                "status": "completed",
                "message": f"{wf.title} butun merheleler tamamlandi!",
                "total_steps": len(wf.steps),
            }

        # Novbeti addim
        next_step = wf.steps[wf.current_step]
        next_step.status = WorkflowStatus.IN_PROGRESS
        next_step.started_at = datetime.now().isoformat()
        wf.status = WorkflowStatus.IN_PROGRESS

        return {
            "workflow_id": wf.workflow_id,
            "current_step": wf.current_step + 1,
            "step_name": next_step.name,
            "progress": f"{wf.current_step}/{len(wf.steps)}",
            "percentage": round(wf.current_step / len(wf.steps) * 100),
        }

    def get_status(self, workflow_id: str) -> dict:
        """Workflow statusu."""
        wf = self.workflows.get(workflow_id)
        if not wf:
            return {"error": "Workflow tapilmadi"}

        return {
            "workflow_id": wf.workflow_id,
            "title": wf.title,
            "type": wf.exam_type,
            "status": wf.status.value,
            "progress": f"{wf.current_step}/{len(wf.steps)}",
            "percentage": round(wf.current_step / len(wf.steps) * 100),
            "steps": [
                {
                    "order": s.order,
                    "name": s.name,
                    "status": s.status.value,
                }
                for s in wf.steps
            ],
        }


# ===== DEMO =====

def run_demo():
    """Workflow demo."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - Imtahan Avtomatlasma Workflow DEMO")
    print("=" * 60)

    engine = WorkflowEngine()

    # Ishe qebul workflow
    wf = engine.create_recruitment_workflow(
        "2026 Riyaziyyat Muellimi Ishe Qebul"
    )
    print(f"\n  Workflow: {wf.title}")
    print(f"  ID: {wf.workflow_id}")
    print(f"  Addim sayi: {len(wf.steps)}")
    print("-" * 60)

    # Butun addimlari kech
    for i in range(len(wf.steps)):
        result = engine.advance_step(wf.workflow_id, {"detail": f"Addim {i+1} tamamlandi"})
        if "step_name" in result:
            print(f"  [{result['percentage']:3d}%] Addim {result['current_step']}: {result['step_name']}")
        else:
            print(f"  [100%] {result.get('message', 'Tamamlandi')}")

    print(f"\n{'='*60}")


if __name__ == "__main__":
    run_demo()
