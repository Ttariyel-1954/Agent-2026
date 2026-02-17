"""
ARTI 2026 - AI Agent Esas Muhurriki
====================================
Tahsil Institutunun butun faaliyyet sahelerini idare eden
merkezi AI Agent sistemi.

Modullar:
- Qiymetlendirme (CAT/MST)
- Sertifikasiya ve Ishe Qebul
- Kurikulum ve Kontent
- Tedqiqat ve Analitika
- Peshkar Inkishaf
- Mekteb Shebekesi
- Beynelxalq Emekdashlig
"""

import asyncio
import logging
from typing import Optional
from datetime import datetime

from agent.core.engine import AgentEngine
from agent.core.router import TaskRouter
from agent.core.state import AgentState
from agent.config.settings import Settings

# Logging konfiqurasiyasi
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger("ARTI_Agent")


class ARTIAgent:
    """
    ARTI Vahid AI Agent
    -------------------
    Bu agent institutun butun faaliyyet sahelerini ehate edir:

    1. assessment   - CAT/MST testler, sual analizi
    2. certification - Muellim imtahanlari, sertifikasiya
    3. curriculum    - Kurikulum, tedris resurslari
    4. research      - Tedqiqat, neshrler, analitika
    5. professional  - Muellim inkishafi, telimler
    6. schools       - Mekteb shebekesi, melumat toplama
    7. international - Olimpiadalar, STEAM, emekdashlig
    8. admin         - Sistem idareetmesi
    """

    def __init__(self, config_path: Optional[str] = None):
        self.settings = Settings(config_path)
        self.state = AgentState()
        self.engine = AgentEngine(self.settings)
        self.router = TaskRouter()
        self.start_time = datetime.now()
        self._plugins_loaded = False

        logger.info("ARTI Agent ishga dushur...")

    async def initialize(self):
        """Agenti tam ishga salir - plugin ve skilleri yukleyir."""
        logger.info("Agent modullargi yuklenilir...")

        # Pluginleri yukle
        await self.engine.load_plugins([
            "assessment",
            "certification",
            "curriculum",
            "research",
            "professional_dev",
            "school_network",
            "international",
        ])

        # Skillleri yukle
        await self.engine.load_skills([
            "cat_testing",
            "mst_testing",
            "item_analysis",
            "exam_management",
            "question_generation",
            "report_generation",
            "data_collection",
            "student_analytics",
            "teacher_evaluation",
            "curriculum_planning",
        ])

        # Yaddashi yukle
        await self.state.load_memory()

        self._plugins_loaded = True
        logger.info(f"Agent hazirdir. {len(self.engine.plugins)} plugin, "
                     f"{len(self.engine.skills)} skill yuklendi.")

    async def process_request(self, user_input: str, context: dict = None) -> dict:
        """
        Istifadechi sorgusunu emal edir.

        Args:
            user_input: Istifadechinin sorgusu
            context: Elave kontekst melumati

        Returns:
            Agent cavabi (dict)
        """
        if not self._plugins_loaded:
            await self.initialize()

        logger.info(f"Sorgu qebul edildi: {user_input[:100]}...")

        # Sorğunu routerden kechir - hansi module yonlendirmeli
        route = await self.router.route(user_input, context)

        logger.info(f"Sorgu yonlendirilir: {route.module} -> {route.skill}")

        # Muvafiğ modula gonder
        result = await self.engine.execute(
            module=route.module,
            skill=route.skill,
            input_data=user_input,
            context=context,
            state=self.state
        )

        # Yaddashi yenile
        await self.state.update_memory(user_input, result)

        return result

    async def get_status(self) -> dict:
        """Agent statusunu qaytarir."""
        uptime = datetime.now() - self.start_time
        return {
            "status": "active",
            "uptime": str(uptime),
            "plugins_loaded": len(self.engine.plugins) if self._plugins_loaded else 0,
            "skills_loaded": len(self.engine.skills) if self._plugins_loaded else 0,
            "total_requests": self.state.request_count,
            "memory_entries": self.state.memory_size,
            "modules": {
                "assessment": "active",
                "certification": "active",
                "curriculum": "active",
                "research": "active",
                "professional_dev": "active",
                "school_network": "active",
                "international": "active",
            }
        }

    async def shutdown(self):
        """Agenti duzgun formada dayandgrgr."""
        logger.info("Agent dayandgirilir...")
        await self.state.save_memory()
        await self.engine.cleanup()
        logger.info("Agent dayandgirildi.")


# ===== CLI Interfeysi =====

async def interactive_mode():
    """Interaktiv terminal rejimi."""
    agent = ARTIAgent()
    await agent.initialize()

    print("\n" + "=" * 60)
    print("  ARTI 2026 - AI Agent Interaktiv Rejim")
    print("  Tahsil Institutunun Vahid Raqamsal Komekcisi")
    print("=" * 60)
    print("\nMovcud komandalar:")
    print("  /status    - Agent statusu")
    print("  /modules   - Modullar siyahisi")
    print("  /help      - Komek")
    print("  /quit      - Chixish")
    print("-" * 60)

    while True:
        try:
            user_input = input("\nARTI> ").strip()

            if not user_input:
                continue

            if user_input == "/quit":
                await agent.shutdown()
                print("Sagolun! ARTI Agent dayandgirildi.")
                break

            if user_input == "/status":
                status = await agent.get_status()
                print(f"\nStatus: {status['status']}")
                print(f"Ishleyish muddeti: {status['uptime']}")
                print(f"Pluginler: {status['plugins_loaded']}")
                print(f"Bacariqlar: {status['skills_loaded']}")
                print(f"Sorgu sayi: {status['total_requests']}")
                continue

            if user_input == "/modules":
                print("\nModullar:")
                print("  1. assessment      - Qiymetlendirme (CAT/MST)")
                print("  2. certification   - Sertifikasiya/Ishe qebul")
                print("  3. curriculum      - Kurikulum/Kontent")
                print("  4. research        - Tedqiqat/Analitika")
                print("  5. professional    - Peshkar inkishaf")
                print("  6. schools         - Mekteb shebekesi")
                print("  7. international   - Beynelxalq")
                continue

            if user_input == "/help":
                print("\nNumune sorgular:")
                print('  "CAT testi yarat 9-cu sinif riyaziyyat ucun"')
                print('  "Muellim sertifikasiya imtahani hazirla"')
                print('  "Son imtahan neticelerini analize et"')
                print('  "STEAM layihesi ucun plan hazirla"')
                print('  "Kurikulum yenilemesi teklifleri ver"')
                continue

            result = await agent.process_request(user_input)
            print(f"\n{result.get('response', 'Sorgu emal edildi.')}")

        except KeyboardInterrupt:
            await agent.shutdown()
            print("\nAgent dayandgirildi.")
            break
        except Exception as e:
            logger.error(f"Xeta: {e}")
            print(f"Xeta bash verdi: {e}")


if __name__ == "__main__":
    asyncio.run(interactive_mode())
