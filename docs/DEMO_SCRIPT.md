# 실습 5 데모 영상 대본

권장 길이: 3–5분. EC2 터미널과 브라우저 주소창이 함께 보이도록 배치합니다.

## 촬영 전

- Learner Lab이 실행 중이고 인스턴스 상태 검사가 통과했는지 확인
- 현재 Public IPv4와 보안 그룹 TCP 80 규칙 확인
- `bash scripts/deploy_ec2.sh`와 `bash scripts/verify_deployment.sh` 성공 확인
- GitHub main에 최신 코드가 push되고 Actions가 통과했는지 확인
- AWS 자격 증명, SSH 키, 계정 ID, 크레딧·결제 정보가 화면에 없는지 확인
- 브라우저에 실제 비밀번호·토큰·개인정보를 입력하지 않음

## 0:00–0:30 · 과제 소개

EC2 인스턴스 이름과 현재 Public IPv4를 보여 주며 설명합니다.

> 실습 4의 courses FastAPI를 Docker로 컨테이너화하고 AWS Learner Lab EC2에
> 배포했습니다. 외부 포트는 80번이고 컨테이너에는 restart always 정책을
> 적용했습니다.

## 0:30–1:20 · 컨테이너 실행 상태

EC2 터미널에서 실행합니다.

```bash
cd fastapi-docker-ec2
sudo docker compose ps
sudo docker ps
```

다음이 화면에 보이도록 잠시 멈춥니다.

- 컨테이너 이름 `fastapi-courses-api`
- 상태 `Up` 및 가능하면 `healthy`
- 포트 `0.0.0.0:80->8000/tcp`

추가로 과제 조건을 짧게 확인할 수 있습니다.

```bash
sudo docker inspect --format '{{.HostConfig.RestartPolicy.Name}}' fastapi-courses-api
```

결과 `always`를 보여 줍니다. 자동 재부팅 장면 자체는 촬영하지 않아도 됩니다.

## 1:20–2:10 · 외부 브라우저 접속

브라우저 주소창에 직접 입력합니다.

```text
http://<현재-EC2-Public-IPv4>/courses
```

주소창에 별도 포트가 없고 JSON list가 표시되는 것을 보여 줍니다. JSON 확인이
불편하면 다음으로 이동해도 됩니다.

```text
http://<현재-EC2-Public-IPv4>/docs
```

## 2:10–3:10 · GET/POST 동작

Swagger `/docs`에서 `GET /courses`를 실행해 200 JSON list를 보여 줍니다. 이어서
`POST /courses`를 다음 네 문자열 필드로 실행합니다.

```json
{
  "course_name": "Docker 영상 확인",
  "year": "2026",
  "semester": "여름학기",
  "grade": "P"
}
```

201 응답이 요청 객체와 동일한지 확인하고 GET을 다시 호출해 목록 마지막에 저장된
장면을 보여 줍니다.

## 3:10–끝 · GitHub와 마무리

공개 GitHub 저장소를 열어 다음을 짧게 보여 줍니다.

- `main.py`, `courses.json`
- `Dockerfile`
- `docker-compose.yml`의 `80:8000`, `restart: always`
- GitHub Actions 성공 상태

마무리 멘트:

> FastAPI courses 서비스가 Docker 컨테이너로 실행 중이며, EC2 호스트 80번을 통해
> 외부 브라우저에서 접근되고 POST 데이터가 JSON 목록에 저장되는 것을 확인했습니다.

## 업로드·제출

- YouTube 공개 범위: **일부 공개(Unlisted)**
- 업로드 시각이 과제 마감보다 늦으면 지연 제출로 처리될 수 있음
- 영상은 **2026-07-20까지 유지**
- 로그아웃 또는 시크릿 창에서 링크 접근 확인
- GitHub repository 주소와 YouTube 링크를 KLAS에 제출
- 일부 공개 영상 링크를 공개 README에 적지 않음
