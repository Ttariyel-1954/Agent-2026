"""
ARTI 2026 - MST (Multi-Stage Testing) Muhurriki
==================================================
Coxseviyyeli Test sistemi.

MST Strukturu (1-3-3 dizayn):
  Stage 1:   [Routing Module]         <- Butun shagirdler eyni modulu alir
  Stage 2:   [Easy] [Medium] [Hard]   <- Stage 1 neticesi ile yonlendirilir
  Stage 3:   [Easy] [Medium] [Hard]   <- Stage 2 neticesi ile yonlendirilir

Xususiyyetler:
- Panel dizayni ve modul teshkili
- IRT esasli routing
- Theta qiymetlendirmesi (her merhelede)
- 7 muxtelif yol (path)
"""

import numpy as np
from typing import List, Dict, Optional, Tuple
from dataclasses import dataclass, field
import logging

logger = logging.getLogger("ARTI.MST")


@dataclass
class MSTItem:
    """MST suali."""
    item_id: str
    a: float
    b: float
    c: float
    content_area: str = ""


@dataclass
class Module:
    """MST modulu - bir merheledeki suallar toplumu."""
    module_id: str
    stage: int
    difficulty_level: str  # "easy", "medium", "hard"
    items: List[MSTItem] = field(default_factory=list)

    @property
    def mean_difficulty(self) -> float:
        if not self.items:
            return 0.0
        return np.mean([item.b for item in self.items])


@dataclass
class Panel:
    """MST paneli - butun merheleler ve modullar."""
    panel_id: str
    stages: Dict[int, List[Module]] = field(default_factory=dict)


@dataclass
class MSTSession:
    """Bir MST sessiyasi."""
    session_id: str
    student_id: str
    panel_id: str
    current_stage: int = 1
    path: List[str] = field(default_factory=list)  # Kechilen modullar
    responses: Dict[str, List[int]] = field(default_factory=dict)
    theta_estimates: Dict[int, float] = field(default_factory=dict)
    is_complete: bool = False


class MSTEngine:
    """
    MST Muhurriki
    ==============
    Lisey ve gimnaziyalarda coxseviyyeli test kechirmek ucun.
    """

    def __init__(self, config: Optional[dict] = None):
        self.config = config or {
            "num_stages": 3,
            "items_per_module": 10,
            "routing_method": "theta",
        }
        self.panels: Dict[str, Panel] = {}
        self.sessions: Dict[str, MSTSession] = {}

    def create_panel(self, panel_id: str, item_bank: List[dict]) -> Panel:
        """
        Panel yaradir - sualları modullar va merheleler üzrə bölüşdürür.

        1-3-3 dizayn:
        - Stage 1: 1 routing modul (orta chesinlik)
        - Stage 2: 3 modul (asan, orta, chetin)
        - Stage 3: 3 modul (asan, orta, chetin)
        """
        panel = Panel(panel_id=panel_id)
        items_per = self.config["items_per_module"]

        # Sualları chesinliye gore sirala
        sorted_items = sorted(item_bank, key=lambda x: x["b"])
        n = len(sorted_items)

        def make_items(raw_items):
            return [MSTItem(**item) for item in raw_items]

        # Stage 1: Orta chesinlikli routing modul
        mid_start = n // 3
        stage1_items = sorted_items[mid_start:mid_start + items_per]
        panel.stages[1] = [
            Module("M1_R", stage=1, difficulty_level="medium",
                   items=make_items(stage1_items))
        ]

        # Stage 2: Asan, Orta, Chetin
        easy_items = sorted_items[:items_per]
        med_items = sorted_items[n // 3: n // 3 + items_per]
        hard_items = sorted_items[2 * n // 3: 2 * n // 3 + items_per]
        panel.stages[2] = [
            Module("M2_E", stage=2, difficulty_level="easy",
                   items=make_items(easy_items)),
            Module("M2_M", stage=2, difficulty_level="medium",
                   items=make_items(med_items)),
            Module("M2_H", stage=2, difficulty_level="hard",
                   items=make_items(hard_items)),
        ]

        # Stage 3: Asan, Orta, Chetin (ferqli suallar)
        easy3 = sorted_items[items_per:2 * items_per]
        med3 = sorted_items[n // 3 + items_per: n // 3 + 2 * items_per]
        hard3 = sorted_items[-(2 * items_per):-items_per] if n > 3 * items_per else sorted_items[-items_per:]
        panel.stages[3] = [
            Module("M3_E", stage=3, difficulty_level="easy",
                   items=make_items(easy3)),
            Module("M3_M", stage=3, difficulty_level="medium",
                   items=make_items(med3)),
            Module("M3_H", stage=3, difficulty_level="hard",
                   items=make_items(hard3)),
        ]

        self.panels[panel_id] = panel
        logger.info(f"Panel yaradildi: {panel_id} (7 modul, 3 merheleli)")
        return panel

    def route_to_module(self, theta: float, stage: int, panel: Panel) -> Module:
        """Theta deyerine gore novbeti modulu sechir."""
        modules = panel.stages[stage]

        if theta >= 0.5:
            return next(m for m in modules if m.difficulty_level == "hard")
        elif theta >= -0.5:
            return next(m for m in modules if m.difficulty_level == "medium")
        else:
            return next(m for m in modules if m.difficulty_level == "easy")

    def estimate_theta(self, session: MSTSession) -> float:
        """Butun cavablar esasinda theta qiymetlendirmesi."""
        all_items = []
        all_responses = []

        panel = self.panels[session.panel_id]
        for module_id, responses in session.responses.items():
            # Modulu tap
            for stage_modules in panel.stages.values():
                for module in stage_modules:
                    if module.module_id == module_id:
                        for i, item in enumerate(module.items):
                            if i < len(responses):
                                all_items.append(item)
                                all_responses.append(responses[i])

        if not all_items:
            return 0.0

        # Sadeleşdirilmiş MLE
        theta = 0.0
        for _ in range(20):
            num = 0
            den = 0
            for item, resp in zip(all_items, all_responses):
                p = item.c + (1 - item.c) / (1 + np.exp(-item.a * (theta - item.b)))
                num += item.a * (resp - p)
                den += item.a ** 2 * p * (1 - p)
            if den == 0:
                break
            theta += num / den
            theta = np.clip(theta, -4, 4)

        return float(theta)

    def start_session(self, session_id: str, student_id: str,
                      panel_id: str) -> dict:
        """Yeni MST sessiyasi bashlayir."""
        session = MSTSession(
            session_id=session_id,
            student_id=student_id,
            panel_id=panel_id,
        )
        self.sessions[session_id] = session

        panel = self.panels[panel_id]
        first_module = panel.stages[1][0]
        session.path.append(first_module.module_id)

        return {
            "status": "in_progress",
            "stage": 1,
            "module_id": first_module.module_id,
            "difficulty": first_module.difficulty_level,
            "items": [
                {
                    "item_id": item.item_id,
                    "difficulty": round(item.b, 2),
                }
                for item in first_module.items
            ],
            "total_items": len(first_module.items),
        }

    def submit_module(self, session_id: str, responses: List[int]) -> dict:
        """Modul cavablarini gonder ve novbeti merheleye kech."""
        session = self.sessions[session_id]
        current_module_id = session.path[-1]
        session.responses[current_module_id] = responses

        # Theta yenile
        theta = self.estimate_theta(session)
        session.theta_estimates[session.current_stage] = theta

        # Novbeti merhele
        session.current_stage += 1

        if session.current_stage > self.config["num_stages"]:
            session.is_complete = True
            return self._finalize_session(session)

        # Novbeti modulu sech
        panel = self.panels[session.panel_id]
        next_module = self.route_to_module(theta, session.current_stage, panel)
        session.path.append(next_module.module_id)

        return {
            "status": "in_progress",
            "stage": session.current_stage,
            "module_id": next_module.module_id,
            "difficulty": next_module.difficulty_level,
            "current_theta": round(theta, 3),
            "routing_decision": f"Theta={theta:.2f} -> {next_module.difficulty_level}",
            "items": [
                {
                    "item_id": item.item_id,
                    "difficulty": round(item.b, 2),
                }
                for item in next_module.items
            ],
            "total_items": len(next_module.items),
        }

    def _finalize_session(self, session: MSTSession) -> dict:
        """Sessiyani yekunlashdirir."""
        final_theta = self.estimate_theta(session)
        total_items = sum(len(r) for r in session.responses.values())
        total_correct = sum(sum(r) for r in session.responses.values())

        path_str = " -> ".join(session.path)

        return {
            "status": "completed",
            "session_id": session.session_id,
            "student_id": session.student_id,
            "final_theta": round(final_theta, 3),
            "path": path_str,
            "modules_completed": session.path,
            "total_items": total_items,
            "correct_responses": total_correct,
            "accuracy": round(total_correct / total_items * 100, 1) if total_items > 0 else 0,
            "theta_by_stage": {
                str(k): round(v, 3) for k, v in session.theta_estimates.items()
            },
            "performance_level": self._classify(final_theta),
        }

    def _classify(self, theta: float) -> str:
        if theta >= 1.5: return "Ela"
        elif theta >= 0.5: return "Yaxshi"
        elif theta >= -0.5: return "Orta"
        elif theta >= -1.5: return "Zeyif"
        else: return "Cox zeyif"


# ===== DEMO =====

def run_demo():
    """MST sistemi demo."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - MST (Coxseviyyeli Test) DEMO")
    print("  Dizayn: 1-3-3 (3 merhele, 7 modul)")
    print("=" * 60)

    np.random.seed(42)

    # Numune sual bazasi (70 sual)
    item_bank = []
    for i in range(70):
        item_bank.append({
            "item_id": f"MST_{i+1:03d}",
            "a": round(np.random.uniform(0.5, 2.5), 2),
            "b": round(np.random.uniform(-3, 3), 2),
            "c": round(np.random.uniform(0.1, 0.25), 2),
            "content_area": np.random.choice(["Cebr", "Hendese", "Statistika"]),
        })

    # MST muhurrik
    engine = MSTEngine({
        "num_stages": 3,
        "items_per_module": 10,
        "routing_method": "theta",
    })

    # Panel yarat
    engine.create_panel("PANEL_01", item_bank)

    # Simulyasiya
    true_theta = 0.8
    print(f"\nSimulyasiya: Heqiqi qabiliyyet (theta) = {true_theta}")
    print("-" * 60)

    # Sessiya bashlat
    result = engine.start_session("MST_DEMO_001", "STUDENT_001", "PANEL_01")
    print(f"\nMerhele 1: {result['module_id']} ({result['difficulty']})")
    print(f"  Sual sayi: {result['total_items']}")

    stage = 1
    while result["status"] == "in_progress":
        module_id = result["module_id"]
        panel = engine.panels["PANEL_01"]

        # Moduldaki suallar ucun cavab simulyasiya et
        module = None
        for stage_modules in panel.stages.values():
            for m in stage_modules:
                if m.module_id == module_id:
                    module = m
                    break

        responses = []
        for item in module.items:
            p = item.c + (1 - item.c) / (1 + np.exp(-item.a * (true_theta - item.b)))
            resp = 1 if np.random.random() < p else 0
            responses.append(resp)

        correct = sum(responses)
        print(f"  Duzgun cavab: {correct}/{len(responses)}")

        result = engine.submit_module("MST_DEMO_001", responses)

        if result["status"] == "in_progress":
            print(f"\nMerhele {result['stage']}: {result['module_id']} "
                  f"({result['difficulty']})")
            print(f"  Routing: {result['routing_decision']}")
            print(f"  Sual sayi: {result['total_items']}")

    # Yekun
    print("\n" + "=" * 60)
    print("  YEKUN NETICE")
    print("=" * 60)
    print(f"  Shagird:              {result['student_id']}")
    print(f"  Qabiliyyet (theta):   {result['final_theta']:+.3f}")
    print(f"  Yol:                  {result['path']}")
    print(f"  Umumy sual:           {result['total_items']}")
    print(f"  Duzgun cavab:         {result['correct_responses']}")
    print(f"  Deqiqlik:             {result['accuracy']}%")
    print(f"  Performans:           {result['performance_level']}")
    print(f"  Heqiqi theta:         {true_theta:+.3f}")
    print(f"  Ferq:                 {abs(result['final_theta'] - true_theta):.3f}")
    print("=" * 60)


if __name__ == "__main__":
    run_demo()
