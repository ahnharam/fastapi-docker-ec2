# 실습 5 제출 체크리스트

## 새 GitHub 저장소

- [ ] 실습 4 저장소를 덮어쓰지 않은 새 `fastapi-docker-ec2` 저장소인가?
- [ ] main 최신 커밋에 모든 제출 파일이 push되었는가?
- [ ] 최종 확인 시 저장소가 public인가?
- [ ] GitHub Actions의 Python과 Docker job이 모두 통과했는가?
- [ ] `.env`, AWS 자격 증명, SSH 키, 실제 계정·AMI 정보가 없는가?

## FastAPI와 데이터

- [ ] `GET /courses`가 JSON list와 200을 반환하는가?
- [ ] `POST /courses`가 `course_name/year/semester/grade` 요청 객체 그대로 201을 반환하는가?
- [ ] POST 객체가 `courses.json` 목록 마지막에 저장되는가?
- [ ] 빈 값·누락·추가 필드가 422로 거부되는가?
- [ ] `/health`가 200과 `status: ok`를 반환하는가?

## Dockerfile

- [ ] 공식 Python slim 기반인가?
- [ ] requirements를 먼저 복사해 의존성 layer cache를 활용하는가?
- [ ] 앱이 UID/GID 10001 비-root로 실행되는가?
- [ ] Uvicorn이 `0.0.0.0:8000`에서 실행되는가?
- [ ] `/health` Docker HEALTHCHECK가 있는가?
- [ ] 이미지에 테스트·문서·키·가상환경이 들어가지 않는가?

## Compose와 EC2

- [ ] 파일명이 정확히 `docker-compose.yml`인가?
- [ ] host `80:8000` mapping인가?
- [ ] `restart: always`인가?
- [ ] 기본 Compose에 volume이 없는가?
- [ ] `sudo systemctl is-enabled docker`가 `enabled`인가?
- [ ] `sudo docker compose ps`에서 api가 Up/healthy인가?
- [ ] `sudo docker ps` 결과와 80번 mapping이 보이는가?
- [ ] `bash scripts/verify_deployment.sh`가 PASS인가?
- [ ] 외부 브라우저에서 `http://<Public-IP>/courses` 또는 `/docs`가 열리는가?

## 영상

- [ ] EC2 터미널 화면이 보이는가?
- [ ] `docker ps` 명령과 실행 중 컨테이너가 보이는가?
- [ ] 브라우저 주소창의 EC2 주소와 FastAPI 응답이 보이는가?
- [ ] `/courses` JSON 또는 `/docs`가 실제로 열리는가?
- [ ] AWS 자격 증명·키·계정 ID·크레딧 정보가 노출되지 않았는가?
- [ ] YouTube가 일부 공개이고 로그아웃 상태에서 열리는가?
- [ ] 업로드 시각이 마감 이전이며 2026-07-20까지 유지 가능한가?

## KLAS 최종 제출

- [ ] 새 GitHub repository 주소를 입력했는가?
- [ ] 일부 공개 YouTube 링크를 입력했는가?
- [ ] 두 링크를 제출 후 다시 열어 확인했는가?
- [ ] Docker Hub 주소는 필수 제출물이 아님을 혼동하지 않았는가?
