"""
ARTI 2026 - Base Plugin
========================
Butun modullar bu baza sinifden miras alir.
"""

from abc import ABC, abstractmethod
from typing import Any, Dict, Optional


class BasePlugin(ABC):
    """Modul plugin baza sinifi."""

    def __init__(self, name: str, version: str = "1.0.0"):
        self.name = name
        self.version = version
        self._active = False

    @abstractmethod
    async def initialize(self, settings: Any) -> bool:
        """Plugini ishga salir."""
        pass

    @abstractmethod
    async def execute(self, skill: str, input_data: str,
                      context: Optional[dict] = None) -> Dict:
        """Mueyyen bacarigi icra edir."""
        pass

    @abstractmethod
    async def get_capabilities(self) -> list:
        """Plugin bacariqlarinin siyahisini qaytarir."""
        pass

    async def health_check(self) -> dict:
        """Plugin sagliq yoxlamasi."""
        return {
            "name": self.name,
            "version": self.version,
            "active": self._active,
            "status": "healthy" if self._active else "inactive"
        }

    async def shutdown(self):
        """Plugini dayandgirgr."""
        self._active = False
