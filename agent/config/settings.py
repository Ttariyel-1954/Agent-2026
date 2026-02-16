"""
ARTI 2026 - Agent Konfiqurasiya
=================================
"""

import os
from dataclasses import dataclass, field
from typing import Optional, Dict, List


@dataclass
class DatabaseConfig:
    host: str = "localhost"
    port: int = 5432
    name: str = "arti_2026"
    user: str = "arti_admin"
    password: str = ""
    ssl_mode: str = "prefer"


@dataclass
class RedisConfig:
    host: str = "localhost"
    port: int = 6379
    password: str = ""
    db: int = 0


@dataclass
class AIConfig:
    model: str = "claude-sonnet-4-5-20250929"
    temperature: float = 0.3
    max_tokens: int = 4096
    memory_enabled: bool = True


@dataclass
class CATConfig:
    """CAT (Computerized Adaptive Testing) konfiqurasiyasi."""
    min_items: int = 10
    max_items: int = 40
    stop_se: float = 0.3
    initial_theta: float = 0.0
    item_selection: str = "maximum_information"
    scoring_method: str = "eap"


@dataclass
class MSTConfig:
    """MST (Multi-Stage Testing) konfiqurasiyasi."""
    num_stages: int = 3
    modules_per_stage: List[int] = field(default_factory=lambda: [1, 3, 3])
    routing_method: str = "maximum_information"
    panel_count: int = 3


@dataclass
class ExamConfig:
    """Imtahan platformasi konfiqurasiyasi."""
    max_concurrent: int = 500
    session_timeout: int = 7200
    auto_submit: bool = True
    shuffle_questions: bool = True
    shuffle_options: bool = True


class Settings:
    """Merkezi konfiqurasiya sinifi."""

    def __init__(self, config_path: Optional[str] = None):
        self.database = DatabaseConfig(
            host=os.getenv("DB_HOST", "localhost"),
            port=int(os.getenv("DB_PORT", "5432")),
            name=os.getenv("DB_NAME", "arti_2026"),
            user=os.getenv("DB_USER", "arti_admin"),
            password=os.getenv("DB_PASSWORD", ""),
        )
        self.redis = RedisConfig(
            host=os.getenv("REDIS_HOST", "localhost"),
            port=int(os.getenv("REDIS_PORT", "6379")),
            password=os.getenv("REDIS_PASSWORD", ""),
        )
        self.ai = AIConfig(
            model=os.getenv("AGENT_MODEL", "claude-sonnet-4-5-20250929"),
            temperature=float(os.getenv("AGENT_TEMPERATURE", "0.3")),
            max_tokens=int(os.getenv("AGENT_MAX_TOKENS", "4096")),
        )
        self.cat = CATConfig()
        self.mst = MSTConfig()
        self.exam = ExamConfig()

        # Umumi
        self.app_name = os.getenv("APP_NAME", "ARTI_2026")
        self.app_env = os.getenv("APP_ENV", "development")
        self.debug = os.getenv("APP_DEBUG", "true").lower() == "true"
        self.port = int(os.getenv("APP_PORT", "8000"))
