"""
ARTI 2026 - Onlayn Netice Toplama API
========================================
Lisey ve gimnaziyalardan real vaxtda test neticelerini toplayan API.

Endpoint-ler:
- POST /api/v1/results/submit       - Netice gonder
- GET  /api/v1/results/school/{id}  - Mekteb neticeleri
- GET  /api/v1/results/student/{id} - Shagird neticeleri
- GET  /api/v1/results/aggregate    - Yekun hesabat
- WS   /ws/results/live             - Real vaxt izleme
"""

from fastapi import FastAPI, HTTPException, WebSocket
from pydantic import BaseModel, Field
from typing import List, Optional, Dict
from datetime import datetime
import json
import uuid

app = FastAPI(
    title="ARTI 2026 - Netice Toplama API",
    description="Lisey ve gimnaziyalardan test neticelerini toplayan sistem",
    version="1.0.0"
)


# ===== Melumat Modelleri =====

class TestResult(BaseModel):
    """Bir shagirdin test neticesi."""
    student_id: str
    school_id: str
    school_name: str
    test_type: str = Field(description="CAT, MST, klassik")
    subject: str
    grade_level: int
    theta: Optional[float] = None
    raw_score: int
    max_score: int
    percentage: float
    duration_seconds: int
    items_administered: int
    responses: Optional[List[dict]] = None
    timestamp: str = Field(default_factory=lambda: datetime.now().isoformat())


class SchoolReport(BaseModel):
    """Mekteb hesabati."""
    school_id: str
    school_name: str
    total_students: int
    avg_score: float
    avg_theta: Optional[float] = None
    pass_rate: float
    by_subject: Dict[str, dict]


class AggregateReport(BaseModel):
    """Yekun (milli) hesabat."""
    total_schools: int
    total_students: int
    avg_score: float
    by_region: Dict[str, dict]
    by_school_type: Dict[str, dict]
    by_subject: Dict[str, dict]


# ===== In-Memory Saxlama (demo ucun) =====
results_store: Dict[str, TestResult] = {}
connected_clients: List[WebSocket] = []


# ===== API Endpoint-leri =====

@app.post("/api/v1/results/submit", response_model=dict)
async def submit_result(result: TestResult):
    """
    Test neticesi gondermek.
    Her mekteb test bitdikden sonra neticeleri bu endpoint-e gonderir.
    """
    result_id = f"R_{uuid.uuid4().hex[:8]}"
    results_store[result_id] = result

    # Real vaxt bildirish (WebSocket)
    notification = {
        "event": "new_result",
        "result_id": result_id,
        "school": result.school_name,
        "student_id": result.student_id,
        "subject": result.subject,
        "score": result.percentage,
        "timestamp": result.timestamp,
    }
    for client in connected_clients:
        try:
            await client.send_json(notification)
        except Exception:
            connected_clients.remove(client)

    return {
        "status": "success",
        "result_id": result_id,
        "message": "Netice ugurla qeyde alindi."
    }


@app.get("/api/v1/results/school/{school_id}")
async def get_school_results(school_id: str):
    """Bir mektebin butun neticelerini qaytarir."""
    school_results = [
        r for r in results_store.values()
        if r.school_id == school_id
    ]

    if not school_results:
        raise HTTPException(404, "Mekteb ucun netice tapilmadi")

    total = len(school_results)
    avg_score = sum(r.percentage for r in school_results) / total

    return {
        "school_id": school_id,
        "school_name": school_results[0].school_name,
        "total_results": total,
        "average_score": round(avg_score, 1),
        "results": [
            {
                "student_id": r.student_id,
                "subject": r.subject,
                "score": r.percentage,
                "theta": r.theta,
                "test_type": r.test_type,
            }
            for r in school_results
        ]
    }


@app.get("/api/v1/results/student/{student_id}")
async def get_student_results(student_id: str):
    """Bir shagirdin butun neticelerini qaytarir."""
    student_results = [
        r for r in results_store.values()
        if r.student_id == student_id
    ]

    if not student_results:
        raise HTTPException(404, "Shagird ucun netice tapilmadi")

    return {
        "student_id": student_id,
        "total_tests": len(student_results),
        "results": [
            {
                "subject": r.subject,
                "test_type": r.test_type,
                "score": r.percentage,
                "theta": r.theta,
                "grade_level": r.grade_level,
                "date": r.timestamp,
            }
            for r in student_results
        ]
    }


@app.get("/api/v1/results/aggregate")
async def get_aggregate_report():
    """Umumi yekun hesabat."""
    all_results = list(results_store.values())

    if not all_results:
        return {"message": "Hele netice yoxdur", "total": 0}

    schools = set(r.school_id for r in all_results)
    total = len(all_results)
    avg = sum(r.percentage for r in all_results) / total

    by_subject = {}
    for r in all_results:
        if r.subject not in by_subject:
            by_subject[r.subject] = {"count": 0, "total_score": 0}
        by_subject[r.subject]["count"] += 1
        by_subject[r.subject]["total_score"] += r.percentage

    for subj in by_subject:
        by_subject[subj]["average"] = round(
            by_subject[subj]["total_score"] / by_subject[subj]["count"], 1
        )

    return {
        "total_schools": len(schools),
        "total_students": total,
        "average_score": round(avg, 1),
        "by_subject": by_subject,
    }


@app.websocket("/ws/results/live")
async def websocket_live_results(websocket: WebSocket):
    """Real vaxt netice izleme (WebSocket)."""
    await websocket.accept()
    connected_clients.append(websocket)
    try:
        while True:
            data = await websocket.receive_text()
            # Ping/pong
            if data == "ping":
                await websocket.send_text("pong")
    except Exception:
        connected_clients.remove(websocket)


@app.get("/api/v1/health")
async def health_check():
    """Sistem sagliq yoxlamasi."""
    return {
        "status": "healthy",
        "service": "ARTI Result Collection API",
        "total_results": len(results_store),
        "timestamp": datetime.now().isoformat(),
    }


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8002)
