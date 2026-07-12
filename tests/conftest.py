"""Shared fixtures that isolate tests from the submitted courses.json file."""

from __future__ import annotations

import json
from collections.abc import Iterator
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from main import CourseRepository, app, get_course_repository


@pytest.fixture
def test_store(tmp_path: Path) -> Path:
    path = tmp_path / "courses.json"
    path.write_text(
        json.dumps(
            [
                {
                    "course_name": "테스트 강의",
                    "year": "2026",
                    "semester": "1학기",
                    "grade": "A+",
                }
            ],
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )
    return path


@pytest.fixture
def client(test_store: Path) -> Iterator[TestClient]:
    repository = CourseRepository(test_store)
    app.dependency_overrides[get_course_repository] = lambda: repository
    try:
        with TestClient(app) as test_client:
            yield test_client
    finally:
        app.dependency_overrides.clear()
