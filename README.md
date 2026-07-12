# FastAPI Courses API · Docker on EC2

실습 4의 `courses` API를 독립된 새 프로젝트로 옮기고, Docker 이미지로 빌드해
AWS Learner Lab EC2의 **호스트 80번 포트**에서 실행하는 실습 5 제출물입니다.
Docker Hub는 사용하지 않으며 EC2에서 저장소를 복제한 뒤 직접 빌드합니다.

## 과제 요구사항 대응

| 요구사항 | 구현 |
|---|---|
| FastAPI 단독 앱 | `main.py`의 `/courses`, `/docs`, `/health` |
| 실습 4 스키마 재사용 | `course_name`, `year`, `semester`, `grade` 문자열 필드 |
| Dockerfile | 공식 `python:3.12-slim-bookworm`, UID 10001 비-root |
| 외부 80번 포트 | Compose `80:8000` |
| 자동 재시작 | Compose `restart: always` |
| 실행 상태 확인 | Docker `HEALTHCHECK`, `scripts/verify_deployment.sh` |
| 새 저장소 | `fastapi-docker-ec2` 전용 프로젝트 |
| Docker Hub | 불필요 — EC2에서 `docker compose up --build -d` |

## API

| Method | Path | 설명 | 정상 응답 |
|---|---|---|---:|
| GET | `/` | 서비스와 엔드포인트 안내 | 200 |
| GET | `/health` | JSON 저장소를 포함한 상태 확인 | 200 |
| GET | `/courses` | `courses.json` 전체 목록 | 200 |
| POST | `/courses` | 요청 객체를 목록 마지막에 원자적으로 저장 | 201 |
| GET | `/docs` | Swagger UI | 200 |

POST 예시:

```json
{
  "course_name": "Docker 컨테이너 실습",
  "year": "2026",
  "semester": "여름학기",
  "grade": "P"
}
```

네 필드는 모두 비어 있지 않은 문자열이어야 하며, 누락·빈 값·추가 필드는
FastAPI가 `422 Unprocessable Entity`로 거부합니다. 정상 POST 응답은 요청 객체와
동일하며, 같은 객체가 `courses.json` 목록 끝에 저장됩니다.

## 로컬 Python 실행

Python 3.11 이상을 권장합니다.

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
python -m pip install -r requirements-dev.txt
python -m uvicorn main:app --host 127.0.0.1 --port 8000
```

브라우저에서 <http://127.0.0.1:8000/courses> 또는
<http://127.0.0.1:8000/docs>를 엽니다.

## Docker 실행

과제와 동일한 Compose 설정은 호스트 80번을 사용합니다.

```bash
docker compose config --quiet
docker compose up --build -d
docker compose ps
curl http://127.0.0.1/courses
```

종료:

```bash
docker compose down
```

호스트 80번을 사용하기 어려운 로컬 개발 환경에서는 Compose 파일을 바꾸지 않고
다음처럼 별도의 임시 컨테이너를 사용할 수 있습니다.

```bash
docker build -t fastapi-courses-api:local .
docker run --rm -p 127.0.0.1:18080:8000 fastapi-courses-api:local
```

이 경우 접속 주소는 <http://127.0.0.1:18080/courses>입니다.

## JSON 영속성과 volume 범위

`CourseRepository`는 동시 쓰기를 잠금으로 직렬화하고 임시 파일을 `fsync`한 뒤
`os.replace`하여 `courses.json`을 원자적으로 교체합니다. 기본 Compose에는 과제에서
요구하지 않은 volume을 넣지 않았습니다.

- 같은 컨테이너의 `docker restart` 및 `restart: always` 재시작: 저장한 데이터 유지
- `docker compose down` 후 재생성 또는 새 이미지로 컨테이너 교체: 이미지의 초기
  `courses.json`으로 돌아갈 수 있음

컨테이너 재생성 뒤에도 데이터를 유지하는 advanced 구성이 필요하면 volume과
`COURSES_FILE` 경로를 추가하고, UID `10001`이 해당 경로를 쓸 수 있게 권한을 설계해야
합니다. 제출 기본값에는 포함하지 않습니다.

## AWS Learner Lab EC2 빠른 배포

Amazon Linux 2023에서 저장소를 복제한 뒤 실행합니다. AMI ID, AWS 키 또는 자격
증명은 프로젝트에 넣지 않습니다.

```bash
sudo dnf install -y git
git clone --depth 1 --branch main https://github.com/ahnharam/fastapi-docker-ec2.git
cd fastapi-docker-ec2

bash scripts/bootstrap_host.sh
bash scripts/deploy_ec2.sh
```

`bootstrap_host.sh`는 다음을 수행합니다.

- 실행 OS가 Amazon Linux 2023인지 확인
- Amazon Linux 저장소에서 Docker Engine과 Git 설치
- `systemctl enable --now docker`
- `docker compose`가 없으면 공식 Docker Compose 릴리스의 플러그인을 다운로드하고
  제공된 SHA-256과 대조한 뒤 시스템 플러그인 경로에 설치

`deploy_ec2.sh`는 내부적으로 다음 과제 명령을 실행하고 검증합니다.

```bash
sudo docker compose up --build -d
sudo docker compose ps
```

외부 브라우저 주소는 `http://<EC2-Public-IPv4>/courses` 또는 `/docs`입니다.
인스턴스·보안 그룹 준비, 최소 인바운드 규칙, 촬영 후 정리는
[EC2 배포 안내](docs/EC2_DEPLOYMENT.md)를 따릅니다.

## Postman

[FastAPI_Docker_EC2.postman_collection.json](postman/FastAPI_Docker_EC2.postman_collection.json)을
가져오면 GET, 정상 POST, 실패하는 POST 요청을 바로 실행할 수 있습니다. Collection
변수 `base_url`의 기본값은 로컬 검증을 위해 `http://127.0.0.1`입니다. EC2 테스트
시에는 일시적으로 `http://<EC2-Public-IPv4>`로 바꿉니다. 자격 증명은 포함하지
않습니다.

## 보안 원칙

- 컨테이너는 root가 아닌 UID/GID `10001:10001`로 실행
- `no-new-privileges`와 Linux capability 전체 제거
- AWS 자격 증명, SSH 키, AMI ID를 코드·문서·이미지에 포함하지 않음
- SSH 22번을 `0.0.0.0/0`에 공개하지 않음
- 80번은 우선 본인 또는 채점자 CIDR로 제한하고, 과제상 전체 공개가 꼭 필요한
  동안만 임시 공개한 뒤 제거
- HTTP 데모에는 비밀번호·토큰·개인정보를 입력하지 않음

## 테스트

```bash
python -m pip install -r requirements-dev.txt
python -m pytest -q
docker compose config --quiet
docker build -t fastapi-courses-api:test .
```

테스트는 제출용 `courses.json`을 건드리지 않고 임시 디렉터리에서 GET, POST,
JSON 저장, 422 validation, 손상된 저장소의 health 응답을 확인합니다. GitHub Actions는
Python 3.11/3.12 테스트와 Docker build·실행·재시작 검증을 수행합니다.

## 프로젝트 구조

```text
fastapi-docker-ec2/
├─ main.py
├─ courses.json
├─ Dockerfile
├─ docker-compose.yml
├─ requirements.txt
├─ requirements-dev.txt
├─ postman/
│  └─ FastAPI_Docker_EC2.postman_collection.json
├─ scripts/
│  ├─ bootstrap_host.sh
│  ├─ deploy_ec2.sh
│  └─ verify_deployment.sh
├─ tests/
│  ├─ conftest.py
│  └─ test_main.py
├─ docs/
│  ├─ EC2_DEPLOYMENT.md
│  ├─ DEMO_SCRIPT.md
│  └─ SUBMISSION_CHECKLIST.md
└─ .github/workflows/tests.yml
```

## 과제·공식 참고 자료

- [실습 5 · Docker](https://kdpark.notion.site/5-Docker-3326afd87d3a8089887afbb4eb589d1f)
- [Docker Compose restart policy](https://docs.docker.com/reference/compose-file/services/#restart)
- [Docker Compose plugin installation](https://docs.docker.com/compose/install/linux/)
- [Amazon Linux 2023 container packages](https://docs.aws.amazon.com/linux/al2023/ug/container.html)
- [FastAPI Docker deployment](https://fastapi.tiangolo.com/deployment/docker/)

## 라이선스

MIT License입니다. 자세한 내용은 [LICENSE](LICENSE)를 확인하세요.
