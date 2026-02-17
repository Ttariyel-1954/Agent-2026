"""
ARTI 2026 - Task Router
========================
Istifadechi sorgularini muvafiq modula yonlendirir.
"""

import re
import logging
from dataclasses import dataclass
from typing import Optional

logger = logging.getLogger("ARTI_Agent.Router")


@dataclass
class Route:
    """Routing neticesi."""
    module: str
    skill: str
    confidence: float
    metadata: Optional[dict] = None


# Achar sozler ve modullar arasinda esleshme
KEYWORD_ROUTES = {
    "assessment": {
        "keywords": [
            "cat", "mst", "test", "qiymetlendirme", "imtahan neticesi",
            "adaptiv", "multistage", "seviyye", "bacariq olcme",
            "item", "sual analiz", "irt", "rasch"
        ],
        "skills": {
            "cat": "cat_testing",
            "mst": "mst_testing",
            "analiz": "item_analysis",
            "irt": "item_analysis",
            "netice": "student_analytics",
        }
    },
    "certification": {
        "keywords": [
            "sertifikasiya", "ishe qebul", "muellim imtahan",
            "sual bazasi", "question bank", "imtahan hazirla",
            "attestasiya", "ixtisas", "kvalifikasiya"
        ],
        "skills": {
            "sertifikasiya": "exam_management",
            "ishe qebul": "exam_management",
            "sual": "question_generation",
            "imtahan": "exam_management",
        }
    },
    "curriculum": {
        "keywords": [
            "kurikulum", "ders", "proqram", "derslik", "metodik",
            "tedris", "kontent", "material", "plan", "movzu"
        ],
        "skills": {
            "kurikulum": "curriculum_planning",
            "plan": "curriculum_planning",
            "kontent": "curriculum_planning",
        }
    },
    "research": {
        "keywords": [
            "tedqiqat", "arashdirma", "neshr", "jurnal", "meqale",
            "statistika", "analitika", "doktorantura", "dissertasiya"
        ],
        "skills": {
            "tedqiqat": "report_generation",
            "analitika": "student_analytics",
            "hesabat": "report_generation",
        }
    },
    "professional_dev": {
        "keywords": [
            "telim", "kurs", "seminar", "inkishaf", "mentorluq",
            "peshkar", "ixtisasartirma", "workshop"
        ],
        "skills": {
            "telim": "teacher_evaluation",
            "kurs": "teacher_evaluation",
        }
    },
    "school_network": {
        "keywords": [
            "mekteb", "lisey", "gimnaziya", "sinif", "shagird",
            "melumat topla", "hesabat", "monitorinq"
        ],
        "skills": {
            "melumat": "data_collection",
            "hesabat": "report_generation",
        }
    },
    "international": {
        "keywords": [
            "olimpiada", "steam", "beynelxalq", "emekdashlig",
            "mubadile", "partnyor", "layihe"
        ],
        "skills": {
            "olimpiada": "report_generation",
            "steam": "curriculum_planning",
        }
    },
}


class TaskRouter:
    """Sorğulari analiz edib muvafiğ modula yonlendirir."""

    def __init__(self):
        self.routes = KEYWORD_ROUTES
        self.history = []

    async def route(self, user_input: str, context: Optional[dict] = None) -> Route:
        """
        Istifadechi sorgusunu analiz edir ve muvafiğ modula yonlendirir.

        Args:
            user_input: Istifadechinin sorgusu
            context: Elave kontekst

        Returns:
            Route obyekti
        """
        input_lower = user_input.lower()
        best_match = None
        best_score = 0

        for module, config in self.routes.items():
            score = 0
            matched_skill = None

            # Achar soz uygunlugu
            for keyword in config["keywords"]:
                if keyword in input_lower:
                    score += 1

            # Skill uygunlugu
            for skill_key, skill_name in config["skills"].items():
                if skill_key in input_lower:
                    matched_skill = skill_name
                    score += 2  # Skill uygunlugu daha yuksek bal

            if score > best_score:
                best_score = score
                best_match = Route(
                    module=module,
                    skill=matched_skill or list(config["skills"].values())[0],
                    confidence=min(score / 5.0, 1.0),
                    metadata={"matched_keywords": score}
                )

        # Eger hech bir uygunlug tapilmasa
        if not best_match or best_score == 0:
            best_match = Route(
                module="assessment",
                skill="cat_testing",
                confidence=0.1,
                metadata={"fallback": True}
            )

        self.history.append({
            "input": user_input[:100],
            "route": best_match
        })

        logger.info(f"Route: {best_match.module}/{best_match.skill} "
                     f"(confidence: {best_match.confidence:.2f})")

        return best_match
