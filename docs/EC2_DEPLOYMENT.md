# AWS Learner Lab EC2 배포 안내

이 문서는 실습 5의 Amazon Linux 2023 기준 배포 절차입니다. 특정 AMI ID, 계정 ID,
리전, 키 이름을 가정하지 않습니다. 실제 클라우드 리소스를 생성·변경하기 전에는
사용자가 리전, 인스턴스 유형, 인바운드 규칙과 비용 영향을 확인해야 합니다.

## 1. 인스턴스와 네트워크 확인

수업에서 제공한 AWS Learner Lab 안에서 공식 Amazon Linux 2023 Standard 이미지를
선택합니다. 실습에서 허용된 인스턴스 유형과 스토리지를 사용하고 Public IPv4가
있는 public subnet을 선택합니다.

권장 최소 인바운드:

| 목적 | Protocol/port | Source |
|---|---|---|
| 브라우저 EC2 Instance Connect | TCP 22 | 해당 리전의 AWS 관리형 EIC prefix list |
| 로컬 SSH를 쓰는 경우 | TCP 22 | 현재 `My IP /32` |
| FastAPI 데모 | TCP 80 | 우선 현재 `My IP /32` 또는 알려진 채점자 CIDR |

- SSH 22번을 `0.0.0.0/0`에 열지 않습니다.
- 채점 방식상 80번 전체 공개가 명시적으로 필요한 경우에만 위험을 확인하고
  `0.0.0.0/0`을 일시 적용한 뒤 제출·확인 후 제거합니다.
- 이 서비스는 HTTP 데모이므로 비밀번호, 토큰, 개인정보를 요청 본문에 넣지 않습니다.

## 2. 저장소 복제

EC2 Instance Connect 또는 수업에서 지시한 방식으로 터미널을 연 뒤 실행합니다.

```bash
cat /etc/os-release
sudo dnf install -y git
git clone --depth 1 --branch main https://github.com/ahnharam/fastapi-docker-ec2.git
cd fastapi-docker-ec2
```

복제 전 GitHub 저장소가 public이고 최신 제출 커밋이 main에 있는지 확인합니다.
토큰을 clone URL에 넣지 않습니다.

## 3. Docker Engine과 Compose 준비

```bash
bash scripts/bootstrap_host.sh
```

스크립트가 수행하는 변경:

1. `/etc/os-release`로 Amazon Linux 2023 확인
2. `dnf`로 Docker Engine과 Git 설치
3. `sudo systemctl enable --now docker`
4. Buildx 플러그인 버전 확인
5. Compose가 요구하는 버전보다 낮으면 공식 Docker Buildx GitHub 릴리스에서 고정
   버전 바이너리와 `checksums.txt`를 HTTPS로 내려받아 검증한 후 시스템 플러그인
   경로에 설치
6. Compose 플러그인 확인
7. 플러그인이 없으면 공식 Docker Compose GitHub 릴리스에서 고정 버전 바이너리와
   `.sha256` 파일을 HTTPS로 내려받고 검증한 후
   `/usr/local/lib/docker/cli-plugins/docker-compose`에 설치

Docker 그룹에는 사용자를 추가하지 않습니다. Docker socket 권한은 사실상 root
권한이므로 배포 명령은 의도적으로 `sudo docker ...`를 사용합니다.

완료 뒤 다음이 모두 버전을 출력해야 합니다.

```bash
sudo docker version
sudo docker buildx version
sudo docker compose version
git --version
```

## 4. 이미지 빌드와 실행

자동 배포·검증:

```bash
bash scripts/deploy_ec2.sh
```

과제의 핵심 명령을 직접 실행하려면 다음과 같습니다.

```bash
sudo docker compose up --build -d
sudo docker compose ps
sudo docker ps
```

기본 Compose 계약:

- host `80` → container `8000`
- `restart: always`
- 비-root UID/GID `10001:10001`
- Dockerfile의 `/health` HEALTHCHECK
- 기본 volume 없음

80번 포트를 이미 다른 프로세스가 사용한다면 다음으로 확인합니다.

```bash
sudo ss -ltnp | grep ':80 ' || true
```

소유자를 모르는 프로세스나 컨테이너를 종료하지 말고, 원인을 확인한 뒤 수업 환경에
맞게 해결합니다. 과제 Compose의 host 포트를 다른 값으로 바꾸면 80번 요구사항을
충족하지 못합니다.

## 5. 배포 검증

```bash
bash scripts/verify_deployment.sh
```

검증 스크립트는 다음을 실패 조건으로 검사합니다.

- `api` 컨테이너 미실행
- restart policy가 `always`가 아님
- `8000/tcp`의 host binding이 `80`이 아님
- 컨테이너가 root 사용자임
- Docker health가 제한 시간 안에 `healthy`가 되지 않음
- `http://127.0.0.1/health` 또는 `/courses` 요청 실패

영상용 수동 확인:

```bash
sudo docker ps
curl -fsS http://127.0.0.1/health
curl -fsS http://127.0.0.1/courses
```

로컬 브라우저에서는 다음 중 하나를 엽니다.

```text
http://<현재-EC2-Public-IPv4>/courses
http://<현재-EC2-Public-IPv4>/docs
```

포트 `:8000`을 붙이지 않습니다. 외부 연결은 host 80번을 사용합니다.

## 6. POST와 JSON 저장 확인

Swagger UI의 `POST /courses` 또는 다음 curl을 사용합니다.

```bash
curl -fsS -X POST http://127.0.0.1/courses \
  -H 'Content-Type: application/json' \
  -d '{"course_name":"Docker 배포","year":"2026","semester":"여름학기","grade":"P"}'
curl -fsS http://127.0.0.1/courses
```

응답 객체가 목록 마지막에 나타납니다. 기본 구성은 volume이 없으므로 같은 컨테이너의
restart에는 남지만 컨테이너를 삭제·재생성하면 초기 데이터로 돌아갈 수 있습니다.
이는 과제에서 허용한 범위입니다.

## 7. 자동 재시작 조건

두 설정이 함께 과제 의도를 충족합니다.

- `systemctl enable docker`: 인스턴스 부팅 시 Docker daemon 시작
- `restart: always`: daemon 시작 뒤 기존 컨테이너 자동 시작

영상에서 재부팅을 시연할 필요는 없습니다. 직접 시험하려면 현재 데이터·세션과
Learner Lab 시간을 확인한 뒤 수행해야 하며, 촬영 직전에 불필요하게 인스턴스를
재부팅하지 않습니다.

## 8. 로그와 문제 해결

```bash
sudo docker compose ps
sudo docker compose logs --tail 100 api
sudo systemctl status docker --no-pager
```

- Compose 없음: `bash scripts/bootstrap_host.sh` 재실행
- container unhealthy: Compose 로그와 `/health` 확인
- 외부에서만 실패: Public IPv4와 보안 그룹 80번 Source 확인
- Stop/Start 뒤 실패: Public IPv4가 바뀌었는지 확인
- POST가 500: `courses.json`과 `/app`이 UID 10001에 쓰기 가능한지 확인

## 9. 촬영 후 비용·노출 정리

1. GitHub와 YouTube 링크가 열리는지 확인합니다.
2. 재촬영이 필요 없으면 사용자 판단으로 EC2를 Stop합니다.
3. 80번을 전체 공개했다면 인바운드 규칙을 제거하거나 제한합니다.
4. Terminate와 볼륨/보안 그룹 삭제는 복구가 어려우므로 제출 확인 뒤 별도로 결정합니다.

AWS 자격 증명, SSH 개인 키, 계정 ID, Learner Lab 크레딧 화면을 영상이나 저장소에
포함하지 않습니다.
