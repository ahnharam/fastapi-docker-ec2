"""FastAPI courses service for the Docker-on-EC2 assignment.

The API intentionally stores data in a JSON file so the behavior from the
previous courses exercise remains visible. Writes are serialized and replace
the data file atomically, which prevents partially-written JSON when a request
is interrupted.
"""

from __future__ import annotations

import json
import logging
import os
import tempfile
import threading
from pathlib import Path
from typing import Annotated, Any

from fastapi import Depends, FastAPI, HTTPException, status
from fastapi.responses import JSONResponse
from pydantic import BaseModel, ConfigDict, Field, ValidationError
from starlette.requests import Request


BASE_DIR = Path(__file__).resolve().parent
DEFAULT_COURSES_FILE = BASE_DIR / "courses.json"
LOGGER = logging.getLogger("courses_api")


class Course(BaseModel):
    """Course schema carried forward from practice 4."""

    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    course_name: str = Field(
        min_length=1,
        max_length=120,
        examples=["오픈소스소프트웨어실습"],
    )
    year: str = Field(min_length=1, max_length=10, examples=["2026"])
    semester: str = Field(min_length=1, max_length=20, examples=["1학기"])
    grade: str = Field(min_length=1, max_length=10, examples=["A+"])


class CourseStoreError(RuntimeError):
    """Raised when the JSON data store cannot be read or written safely."""


class CourseRepository:
    """Thread-safe JSON repository with atomic writes."""

    def __init__(self, path: Path) -> None:
        self.path = path
        self._lock = threading.Lock()

    def list_courses(self) -> list[Course]:
        with self._lock:
            return self._read_unlocked()

    def create_course(self, payload: Course) -> Course:
        with self._lock:
            courses = self._read_unlocked()
            courses.append(payload)
            self._write_unlocked(courses)
            return payload

    def _read_unlocked(self) -> list[Course]:
        try:
            raw: Any = json.loads(self.path.read_text(encoding="utf-8"))
        except FileNotFoundError as exc:
            raise CourseStoreError("The courses data file does not exist.") from exc
        except (OSError, json.JSONDecodeError) as exc:
            raise CourseStoreError("The courses data file could not be read.") from exc

        if not isinstance(raw, list):
            raise CourseStoreError("The courses data root must be a JSON list.")

        try:
            return [Course.model_validate(item) for item in raw]
        except ValidationError as exc:
            raise CourseStoreError("The courses data contains an invalid record.") from exc

    def _write_unlocked(self, courses: list[Course]) -> None:
        self.path.parent.mkdir(parents=True, exist_ok=True)
        temporary_path: Path | None = None

        try:
            with tempfile.NamedTemporaryFile(
                mode="w",
                encoding="utf-8",
                dir=self.path.parent,
                prefix=f".{self.path.name}.",
                suffix=".tmp",
                delete=False,
            ) as temporary_file:
                temporary_path = Path(temporary_file.name)
                json.dump(
                    [course.model_dump() for course in courses],
                    temporary_file,
                    ensure_ascii=False,
                    indent=2,
                )
                temporary_file.write("\n")
                temporary_file.flush()
                os.fsync(temporary_file.fileno())

            os.replace(temporary_path, self.path)
        except OSError as exc:
            if temporary_path is not None:
                temporary_path.unlink(missing_ok=True)
            raise CourseStoreError("The courses data file could not be written.") from exc


def _configured_courses_path() -> Path:
    configured = os.getenv("COURSES_FILE")
    if not configured:
        return DEFAULT_COURSES_FILE
    return Path(configured).expanduser().resolve()


COURSE_REPOSITORY = CourseRepository(_configured_courses_path())


def get_course_repository() -> CourseRepository:
    """FastAPI dependency that can be replaced by tests."""

    return COURSE_REPOSITORY


RepositoryDependency = Annotated[CourseRepository, Depends(get_course_repository)]

app = FastAPI(
    title="Courses API · Docker on EC2",
    description=(
        "실습 5 제출용 FastAPI 서비스입니다. Docker 컨테이너에서 실행되고 "
        "JSON 파일에 강의 데이터를 저장합니다."
    ),
    version="1.0.0",
)


@app.exception_handler(CourseStoreError)
async def course_store_error_handler(
    _request: Request, exc: CourseStoreError
) -> JSONResponse:
    LOGGER.error("course_store_error: %s", exc)
    return JSONResponse(
        status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
        content={"detail": "Course data is unavailable."},
    )


@app.get("/", tags=["service"])
def service_info() -> dict[str, Any]:
    return {
        "service": "Courses API",
        "assignment": "실습 5 · Docker",
        "endpoints": {"courses": "/courses", "docs": "/docs", "health": "/health"},
    }


@app.get("/health", tags=["service"])
def health_check(repository: RepositoryDependency) -> dict[str, Any]:
    try:
        course_count = len(repository.list_courses())
    except CourseStoreError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Course data is unavailable.",
        ) from exc
    return {"status": "ok", "course_count": course_count}


@app.get("/courses", response_model=list[Course], tags=["courses"])
def list_courses(repository: RepositoryDependency) -> list[Course]:
    return repository.list_courses()


@app.post(
    "/courses",
    response_model=Course,
    status_code=status.HTTP_201_CREATED,
    tags=["courses"],
)
def create_course(payload: Course, repository: RepositoryDependency) -> Course:
    created = repository.create_course(payload)
    LOGGER.info("course_created course_name=%s", created.course_name)
    return created
