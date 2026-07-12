"""API and JSON persistence tests."""

from __future__ import annotations

import json
from pathlib import Path

from fastapi.testclient import TestClient


def test_service_info_and_health(client: TestClient) -> None:
    root_response = client.get("/")
    health_response = client.get("/health")

    assert root_response.status_code == 200
    assert root_response.json()["service"] == "Courses API"
    assert health_response.status_code == 200
    assert health_response.json() == {"status": "ok", "course_count": 1}


def test_get_courses_returns_json_list(client: TestClient) -> None:
    response = client.get("/courses")

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("application/json")
    assert response.json() == [
        {
            "course_name": "테스트 강의",
            "year": "2026",
            "semester": "1학기",
            "grade": "A+",
        }
    ]


def test_post_course_persists_to_json(client: TestClient, test_store: Path) -> None:
    payload = {
        "course_name": "Docker 실습",
        "year": "2026",
        "semester": "여름학기",
        "grade": "P",
    }

    response = client.post("/courses", json=payload)

    assert response.status_code == 201
    assert response.json() == payload
    assert client.get("/courses").json()[-1] == payload

    persisted = json.loads(test_store.read_text(encoding="utf-8"))
    assert persisted[-1] == payload


def test_invalid_course_is_rejected_without_writing(
    client: TestClient, test_store: Path
) -> None:
    before = test_store.read_text(encoding="utf-8")

    response = client.post(
        "/courses",
        json={
            "course_name": " ",
            "year": "2026",
            "semester": "1학기",
            "grade": "A+",
        },
    )

    assert response.status_code == 422
    assert test_store.read_text(encoding="utf-8") == before
    assert client.get("/courses").json() == [
        {
            "course_name": "테스트 강의",
            "year": "2026",
            "semester": "1학기",
            "grade": "A+",
        }
    ]


def test_health_reports_unavailable_store(client: TestClient, test_store: Path) -> None:
    test_store.write_text("not-json", encoding="utf-8")

    response = client.get("/health")

    assert response.status_code == 503
    assert response.json() == {"detail": "Course data is unavailable."}
