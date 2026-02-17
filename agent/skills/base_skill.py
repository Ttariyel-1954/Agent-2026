"""
ARTI 2026 - Base Skill
=======================
Agent bacariqlarinin baza sinifi.
"""

from abc import ABC, abstractmethod
from typing import Any, Dict, Optional


class BaseSkill(ABC):
    """Bacariq baza sinifi."""

    def __init__(self, name: str, description: str):
        self.name = name
        self.description = description

    @abstractmethod
    async def run(self, input_data: str, params: Optional[dict] = None) -> Dict:
        """Bacarigi icra edir."""
        pass

    def validate_input(self, input_data: str) -> bool:
        """Girishi yoxlayir."""
        return bool(input_data and input_data.strip())


class CATTestingSkill(BaseSkill):
    """CAT test yaratma bacarigi."""

    def __init__(self):
        super().__init__(
            name="cat_testing",
            description="Komputer Adaptiv Test yaratma ve idare etme"
        )

    async def run(self, input_data: str, params: Optional[dict] = None) -> Dict:
        return {
            "skill": self.name,
            "action": "cat_test_created",
            "response": "CAT test ugurla yaradildi.",
            "details": params
        }


class MSTTestingSkill(BaseSkill):
    """MST test yaratma bacarigi."""

    def __init__(self):
        super().__init__(
            name="mst_testing",
            description="Coxseviyyeli Test yaratma ve idare etme"
        )

    async def run(self, input_data: str, params: Optional[dict] = None) -> Dict:
        return {
            "skill": self.name,
            "action": "mst_test_created",
            "response": "MST test ugurla yaradildi.",
            "details": params
        }


class QuestionGenerationSkill(BaseSkill):
    """Sual yaratma bacarigi."""

    def __init__(self):
        super().__init__(
            name="question_generation",
            description="AI ile sual yaratma ve redakte etme"
        )

    async def run(self, input_data: str, params: Optional[dict] = None) -> Dict:
        return {
            "skill": self.name,
            "action": "questions_generated",
            "response": "Suallar ugurla yaradildi.",
            "details": params
        }


class ExamManagementSkill(BaseSkill):
    """Imtahan idareetme bacarigi."""

    def __init__(self):
        super().__init__(
            name="exam_management",
            description="Imtahanlarin planlaşdirilmasi ve idaresi"
        )

    async def run(self, input_data: str, params: Optional[dict] = None) -> Dict:
        return {
            "skill": self.name,
            "action": "exam_managed",
            "response": "Imtahan ugurla idare edildi.",
            "details": params
        }


class ReportGenerationSkill(BaseSkill):
    """Hesabat yaratma bacarigi."""

    def __init__(self):
        super().__init__(
            name="report_generation",
            description="Avtomatik hesabat yaratma"
        )

    async def run(self, input_data: str, params: Optional[dict] = None) -> Dict:
        return {
            "skill": self.name,
            "action": "report_generated",
            "response": "Hesabat ugurla yaradildi.",
            "details": params
        }
