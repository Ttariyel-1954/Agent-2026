"""
ARTI 2026 - Autentifikasiya Xidmeti
======================================
JWT esasli autentifikasiya ve avtorizasiya.
"""

from datetime import datetime, timedelta
from typing import Optional, Dict
import hashlib
import secrets
import json


class AuthService:
    """Autentifikasiya xidmeti."""

    def __init__(self, secret_key: str = "arti-2026-secret"):
        self.secret_key = secret_key
        # Demo istifadechi bazasi
        self.users: Dict[str, dict] = {}
        self.tokens: Dict[str, dict] = {}
        self.roles_permissions = {
            "admin": ["*"],
            "school_admin": [
                "schools:read", "schools:write",
                "students:read", "teachers:read",
                "results:read", "reports:read",
            ],
            "teacher": [
                "students:read", "results:read",
                "items:create", "items:read",
                "courses:read",
            ],
            "student": [
                "exams:take", "results:read_own",
                "courses:read",
            ],
            "examiner": [
                "exams:create", "exams:manage",
                "items:create", "items:review",
                "results:read", "reports:create",
            ],
            "researcher": [
                "data:read", "analytics:read",
                "publications:create", "reports:create",
            ],
        }

    def hash_password(self, password: str) -> str:
        """Shifreni hash edir."""
        salt = self.secret_key
        return hashlib.sha256(f"{salt}{password}".encode()).hexdigest()

    def register(self, email: str, password: str, full_name: str,
                 role: str) -> dict:
        """Istifadechi qeydiyyati."""
        if email in self.users:
            return {"error": "Bu email artiq qeydiyyatda"}

        user_id = secrets.token_hex(16)
        self.users[email] = {
            "user_id": user_id,
            "email": email,
            "password_hash": self.hash_password(password),
            "full_name": full_name,
            "role": role,
            "is_active": True,
            "created_at": datetime.now().isoformat(),
        }
        return {"user_id": user_id, "message": "Qeydiyyat ugurlu"}

    def login(self, email: str, password: str) -> Optional[dict]:
        """Giris."""
        user = self.users.get(email)
        if not user:
            return None
        if user["password_hash"] != self.hash_password(password):
            return None
        if not user["is_active"]:
            return None

        # Token yarat
        token = secrets.token_hex(32)
        self.tokens[token] = {
            "user_id": user["user_id"],
            "email": email,
            "role": user["role"],
            "created_at": datetime.now().isoformat(),
            "expires_at": (datetime.now() + timedelta(hours=24)).isoformat(),
        }

        return {
            "access_token": token,
            "token_type": "bearer",
            "expires_in": 86400,
            "user": {
                "user_id": user["user_id"],
                "email": email,
                "full_name": user["full_name"],
                "role": user["role"],
            }
        }

    def verify_token(self, token: str) -> Optional[dict]:
        """Tokeni yoxlayir."""
        token_data = self.tokens.get(token)
        if not token_data:
            return None
        if datetime.fromisoformat(token_data["expires_at"]) < datetime.now():
            del self.tokens[token]
            return None
        return token_data

    def check_permission(self, role: str, permission: str) -> bool:
        """Icaze yoxlamasi."""
        perms = self.roles_permissions.get(role, [])
        return "*" in perms or permission in perms
