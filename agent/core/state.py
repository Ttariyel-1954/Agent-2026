"""
ARTI 2026 - Agent State Manager
=================================
Agentin yaddashini ve veziyyetini idare edir.
"""

import json
import os
import logging
from datetime import datetime
from typing import Dict, Any, List, Optional

logger = logging.getLogger("ARTI_Agent.State")

MEMORY_DIR = os.path.join(os.path.dirname(__file__), "..", "memory")


class AgentState:
    """Agent veziyyeti ve yaddash idareetmesi."""

    def __init__(self):
        self.request_count: int = 0
        self.memory: Dict[str, Any] = {}
        self.conversation_history: List[dict] = []
        self.session_start: datetime = datetime.now()
        self.current_context: Optional[dict] = None

    @property
    def memory_size(self) -> int:
        return len(self.memory)

    async def load_memory(self):
        """Yaddashi diskden yukleyir."""
        memory_file = os.path.join(MEMORY_DIR, "agent_memory.json")
        try:
            if os.path.exists(memory_file):
                with open(memory_file, "r", encoding="utf-8") as f:
                    self.memory = json.load(f)
                logger.info(f"Yaddash yuklendi: {len(self.memory)} qeyd")
            else:
                self.memory = {
                    "created_at": datetime.now().isoformat(),
                    "institute": "ARTI",
                    "version": "2026.1.0",
                    "preferences": {},
                    "learned_patterns": [],
                    "frequently_used": {},
                }
                await self.save_memory()
                logger.info("Yeni yaddash yaradildi.")
        except Exception as e:
            logger.error(f"Yaddash yukleme xetasi: {e}")
            self.memory = {}

    async def save_memory(self):
        """Yaddashi diske yazir."""
        memory_file = os.path.join(MEMORY_DIR, "agent_memory.json")
        try:
            os.makedirs(MEMORY_DIR, exist_ok=True)
            with open(memory_file, "w", encoding="utf-8") as f:
                json.dump(self.memory, f, indent=2, ensure_ascii=False)
            logger.info("Yaddash saxlandi.")
        except Exception as e:
            logger.error(f"Yaddash saxlama xetasi: {e}")

    async def update_memory(self, user_input: str, result: dict):
        """Yaddashi yeni melumatlala yenileyir."""
        self.conversation_history.append({
            "timestamp": datetime.now().isoformat(),
            "input": user_input[:200],
            "module": result.get("module", "unknown"),
            "skill": result.get("skill", "unknown"),
            "status": result.get("status", "unknown"),
        })

        # Tez-tez istifade olunan modullari izle
        module = result.get("module", "unknown")
        freq = self.memory.get("frequently_used", {})
        freq[module] = freq.get(module, 0) + 1
        self.memory["frequently_used"] = freq

    def get_recent_context(self, n: int = 5) -> List[dict]:
        """Son n sorğu kontekstini qaytarir."""
        return self.conversation_history[-n:]
