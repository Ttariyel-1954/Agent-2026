"""
ARTI 2026 - CAT Engine Unit Testleri
=======================================
pytest tests/unit/modules/test_cat_engine.py -v
"""

import pytest
import numpy as np
import sys
import os

sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "..", ".."))
from modules.assessment.cat.engine.cat_engine import CATEngine, Item


@pytest.fixture
def cat_engine():
    """CAT muhurrik instance."""
    engine = CATEngine({
        "min_items": 5,
        "max_items": 20,
        "stop_se": 0.4,
        "initial_theta": 0.0,
    })
    # Numune sual bazasi
    np.random.seed(42)
    items = [
        {
            "item_id": f"TEST_{i:03d}",
            "a": round(np.random.uniform(0.5, 2.5), 2),
            "b": round(np.random.uniform(-3, 3), 2),
            "c": round(np.random.uniform(0.1, 0.3), 2),
        }
        for i in range(30)
    ]
    engine.load_item_bank(items)
    return engine


class TestCATEngine:
    """CAT muhurrik testleri."""

    def test_item_bank_loaded(self, cat_engine):
        """Sual bazasi duzgun yuklenmelidir."""
        assert len(cat_engine.item_bank) == 30

    def test_probability_range(self, cat_engine):
        """Ehtimal 0-1 arasinda olmalidir."""
        item = cat_engine.item_bank[0]
        for theta in np.linspace(-4, 4, 20):
            p = cat_engine.probability(theta, item)
            assert 0 <= p <= 1

    def test_probability_monotonic(self, cat_engine):
        """Ehtimal theta artdiqca artmalidir."""
        item = cat_engine.item_bank[0]
        prev_p = 0
        for theta in np.linspace(-4, 4, 20):
            p = cat_engine.probability(theta, item)
            assert p >= prev_p
            prev_p = p

    def test_information_non_negative(self, cat_engine):
        """Informasiya menfi olmamalidir."""
        item = cat_engine.item_bank[0]
        for theta in np.linspace(-4, 4, 20):
            info = cat_engine.information(theta, item)
            assert info >= 0

    def test_start_session(self, cat_engine):
        """Sessiya duzgun bashlayir."""
        session = cat_engine.start_session("S001", "STU001")
        assert session.session_id == "S001"
        assert session.student_id == "STU001"
        assert session.theta == 0.0
        assert not session.is_complete

    def test_administer_item(self, cat_engine):
        """Sual verilmesi duzgun isleyir."""
        cat_engine.start_session("S002", "STU002")
        result = cat_engine.administer_item("S002", 0)
        assert result["status"] == "in_progress"
        assert "item" in result

    def test_session_completes(self, cat_engine):
        """Sessiya tamamlanir."""
        cat_engine.start_session("S003", "STU003")
        result = cat_engine.administer_item("S003", 0)

        for _ in range(30):
            if result["status"] == "completed":
                break
            response = np.random.randint(0, 2)
            result = cat_engine.administer_item("S003", response)

        assert result["status"] == "completed"
        assert "final_theta" in result
        assert "performance_level" in result

    def test_theta_estimation(self, cat_engine):
        """Theta qiymetlendirmesi isleyir."""
        session = cat_engine.start_session("S004", "STU004")
        session.items_administered = [cat_engine.item_bank[0].item_id]
        session.responses = [1]

        theta, se = cat_engine.estimate_theta_eap(session)
        assert isinstance(theta, float)
        assert isinstance(se, float)
        assert -4 <= theta <= 4


if __name__ == "__main__":
    pytest.main([__file__, "-v"])
