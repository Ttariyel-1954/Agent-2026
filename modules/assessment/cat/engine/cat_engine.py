"""
ARTI 2026 - CAT (Computerized Adaptive Testing) Muhurriki
============================================================
Komputer Adaptiv Test sistemi.
IRT (Item Response Theory) esasli adaptiv test.

Xususiyyetler:
- 3PL IRT modeli (a, b, c parametrleri)
- Maximum Information item sechimi
- EAP/MLE qabiliyyet qiymetlendirmesi
- Standart xeta esasli dayanma qaydasi
- Real vaxt netice hesablamasi
"""

import numpy as np
from typing import List, Dict, Tuple, Optional
from dataclasses import dataclass, field
import json
import logging

logger = logging.getLogger("ARTI.CAT")


@dataclass
class Item:
    """Test suali (item)."""
    item_id: str
    a: float  # Ayird etme parametri (discrimination)
    b: float  # Chesinlik parametri (difficulty)
    c: float  # Tesedufi tapma parametri (guessing)
    content_area: str = ""
    item_text: str = ""
    options: List[str] = field(default_factory=list)
    correct_answer: int = 0
    used: bool = False


@dataclass
class CATSession:
    """Bir CAT sessiyasi."""
    session_id: str
    student_id: str
    theta: float = 0.0          # Qabiliyyet sehiyyesi
    se: float = 1.0             # Standart xeta
    items_administered: List[str] = field(default_factory=list)
    responses: List[int] = field(default_factory=list)
    theta_history: List[float] = field(default_factory=list)
    se_history: List[float] = field(default_factory=list)
    is_complete: bool = False


class CATEngine:
    """
    CAT Muhurriki
    ==============
    Lisey ve gimnaziyalarda adaptiv test kechirmek ucun.
    """

    def __init__(self, config: Optional[dict] = None):
        self.config = config or {
            "min_items": 10,
            "max_items": 40,
            "stop_se": 0.3,
            "initial_theta": 0.0,
        }
        self.item_bank: List[Item] = []
        self.sessions: Dict[str, CATSession] = {}

    def load_item_bank(self, items: List[dict]):
        """Sual bazasini yukleyir."""
        self.item_bank = [
            Item(
                item_id=item["item_id"],
                a=item["a"],
                b=item["b"],
                c=item["c"],
                content_area=item.get("content_area", ""),
                item_text=item.get("item_text", ""),
                options=item.get("options", []),
                correct_answer=item.get("correct_answer", 0),
            )
            for item in items
        ]
        logger.info(f"Sual bazasi yuklendi: {len(self.item_bank)} sual")

    def probability(self, theta: float, item: Item) -> float:
        """3PL IRT modeli ile duzgun cavab ehtimalini hesablayir."""
        exponent = -item.a * (theta - item.b)
        return item.c + (1 - item.c) / (1 + np.exp(exponent))

    def information(self, theta: float, item: Item) -> float:
        """Fisher informasiya funksiyasi."""
        p = self.probability(theta, item)
        q = 1 - p
        if p <= item.c or q <= 0:
            return 0.0
        numerator = (item.a ** 2) * ((p - item.c) ** 2) * q
        denominator = ((1 - item.c) ** 2) * p
        if denominator == 0:
            return 0.0
        return numerator / denominator

    def select_next_item(self, session: CATSession) -> Optional[Item]:
        """
        Maximum Information usulu ile novbeti suali sechir.
        En chox melumat veren istifade olunmamiş suali sechir.
        """
        available = [
            item for item in self.item_bank
            if item.item_id not in session.items_administered
        ]

        if not available:
            return None

        # Her sual ucun informasiya hesabla
        item_info = [
            (item, self.information(session.theta, item))
            for item in available
        ]

        # En yuksek informasiyali suali sech
        best_item = max(item_info, key=lambda x: x[1])[0]
        return best_item

    def estimate_theta_eap(self, session: CATSession) -> Tuple[float, float]:
        """
        EAP (Expected A Posteriori) usulu ile theta qiymetlendirmesi.
        """
        quad_points = np.linspace(-4, 4, 61)
        prior = np.exp(-0.5 * quad_points ** 2) / np.sqrt(2 * np.pi)

        likelihood = np.ones_like(quad_points)
        for i, item_id in enumerate(session.items_administered):
            item = next(it for it in self.item_bank if it.item_id == item_id)
            p = np.array([self.probability(q, item) for q in quad_points])
            if session.responses[i] == 1:
                likelihood *= p
            else:
                likelihood *= (1 - p)

        posterior = likelihood * prior
        posterior_sum = np.sum(posterior)

        if posterior_sum == 0:
            return 0.0, 1.0

        posterior /= posterior_sum

        # Theta qiymeti (gozlenilen deyer)
        theta = np.sum(quad_points * posterior)

        # Standart xeta
        variance = np.sum((quad_points - theta) ** 2 * posterior)
        se = np.sqrt(variance)

        return float(theta), float(se)

    def start_session(self, session_id: str, student_id: str) -> CATSession:
        """Yeni CAT sessiyasi bashlayir."""
        session = CATSession(
            session_id=session_id,
            student_id=student_id,
            theta=self.config["initial_theta"],
        )
        self.sessions[session_id] = session
        logger.info(f"CAT sessiya bashladi: {session_id} (shagird: {student_id})")
        return session

    def administer_item(self, session_id: str, response: int) -> dict:
        """
        Cavabi qeyd edir, theta yenileyir, novbeti suali sechir.

        Args:
            session_id: Sessiya ID
            response: Cavab (1=duzgun, 0=sehv)

        Returns:
            Novbeti sual ve ya test neticesi
        """
        session = self.sessions[session_id]

        # Eger bu ilk sual deyilse, cavabi qeyd et
        if len(session.items_administered) > len(session.responses):
            session.responses.append(response)

            # Theta yenile
            theta, se = self.estimate_theta_eap(session)
            session.theta = theta
            session.se = se
            session.theta_history.append(theta)
            session.se_history.append(se)

        # Dayanma qaydasini yoxla
        n_items = len(session.responses)
        if n_items >= self.config["min_items"]:
            if (session.se <= self.config["stop_se"] or
                    n_items >= self.config["max_items"]):
                session.is_complete = True
                return self._finalize_session(session)

        # Novbeti suali sech
        next_item = self.select_next_item(session)
        if not next_item:
            session.is_complete = True
            return self._finalize_session(session)

        session.items_administered.append(next_item.item_id)

        return {
            "status": "in_progress",
            "item_number": len(session.items_administered),
            "item": {
                "item_id": next_item.item_id,
                "item_text": next_item.item_text,
                "options": next_item.options,
                "content_area": next_item.content_area,
            },
            "current_theta": round(session.theta, 3),
            "current_se": round(session.se, 3),
            "items_remaining_min": max(0, self.config["min_items"] - n_items),
            "items_remaining_max": self.config["max_items"] - n_items,
        }

    def _finalize_session(self, session: CATSession) -> dict:
        """Sessiyani yekunlashdirir ve netice qaytarir."""
        n_correct = sum(session.responses)
        n_total = len(session.responses)

        return {
            "status": "completed",
            "session_id": session.session_id,
            "student_id": session.student_id,
            "final_theta": round(session.theta, 3),
            "final_se": round(session.se, 3),
            "items_administered": n_total,
            "correct_responses": n_correct,
            "accuracy": round(n_correct / n_total * 100, 1) if n_total > 0 else 0,
            "theta_history": [round(t, 3) for t in session.theta_history],
            "se_history": [round(s, 3) for s in session.se_history],
            "performance_level": self._classify_performance(session.theta),
        }

    def _classify_performance(self, theta: float) -> str:
        """Theta deyerine gore performans seviyyesini mueyyen edir."""
        if theta >= 1.5:
            return "Ela"
        elif theta >= 0.5:
            return "Yaxshi"
        elif theta >= -0.5:
            return "Orta"
        elif theta >= -1.5:
            return "Zeyif"
        else:
            return "Cox zeyif"


# ===== DEMO =====

def run_demo():
    """CAT sistemi demo - numune test simulyasiyasi."""
    print("\n" + "=" * 60)
    print("  ARTI 2026 - CAT (Komputer Adaptiv Test) DEMO")
    print("=" * 60)

    # Numune sual bazasi (50 sual)
    np.random.seed(42)
    sample_items = []
    for i in range(50):
        sample_items.append({
            "item_id": f"MATH_{i+1:03d}",
            "a": round(np.random.uniform(0.5, 2.5), 2),  # Ayird etme
            "b": round(np.random.uniform(-3, 3), 2),      # Chesinlik
            "c": round(np.random.uniform(0.1, 0.3), 2),   # Tesedufi tapma
            "content_area": np.random.choice(["Cebr", "Hendese", "Statistika", "Analiz"]),
            "item_text": f"Riyaziyyat suali #{i+1}",
            "options": ["A", "B", "C", "D"],
            "correct_answer": np.random.randint(0, 4),
        })

    # CAT muhurrikini yarat
    engine = CATEngine({
        "min_items": 10,
        "max_items": 30,
        "stop_se": 0.35,
        "initial_theta": 0.0,
    })
    engine.load_item_bank(sample_items)

    # Sessiya bashlat
    session = engine.start_session("DEMO_001", "STUDENT_001")

    # Simulyasiya: theta=1.0 olan shagird
    true_theta = 1.0
    print(f"\nSimulyasiya: Heqiqi qabiliyyet (theta) = {true_theta}")
    print(f"Minimum sual: {engine.config['min_items']}")
    print(f"Maksimum sual: {engine.config['max_items']}")
    print(f"Dayanma SE: {engine.config['stop_se']}")
    print("-" * 60)

    # Ilk suali al
    result = engine.administer_item("DEMO_001", 0)

    step = 1
    while result["status"] == "in_progress":
        item_id = result["item"]["item_id"]
        # Heqiqi theta esasinda cavab simulyasiya et
        item = next(it for it in engine.item_bank if it.item_id == item_id)
        p = engine.probability(true_theta, item)
        response = 1 if np.random.random() < p else 0

        print(f"  Sual {step:2d}: {item_id} | "
              f"b={item.b:+.2f} | "
              f"Cavab: {'Duzgun' if response else 'Sehv':6s} | "
              f"Theta: {result['current_theta']:+.3f} | "
              f"SE: {result['current_se']:.3f}")

        result = engine.administer_item("DEMO_001", response)
        step += 1

    # Yekun netice
    print("\n" + "=" * 60)
    print("  YEKUN NETICE")
    print("=" * 60)
    print(f"  Shagird:              {result['student_id']}")
    print(f"  Qabiliyyet (theta):   {result['final_theta']:+.3f}")
    print(f"  Standart xeta:        {result['final_se']:.3f}")
    print(f"  Verilmish sual sayi:  {result['items_administered']}")
    print(f"  Duzgun cavab:         {result['correct_responses']}")
    print(f"  Deqiqlik:             {result['accuracy']}%")
    print(f"  Performans seviyyesi: {result['performance_level']}")
    print(f"  Heqiqi theta:         {true_theta:+.3f}")
    print(f"  Ferq:                 {abs(result['final_theta'] - true_theta):.3f}")
    print("=" * 60)


if __name__ == "__main__":
    run_demo()
