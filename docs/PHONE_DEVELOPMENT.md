# Pocket 3DS 개발과 설치

아이폰 15에서 사용할 개인용 Manic EMU 파생 앱이다. 첫 단계는 기존 게임
실행 기능과 JIT를 유지하면서, 폰으로 수정 요청을 보내고 새 IPA를 받는
흐름을 만드는 것이다. 첫 빌드는 원본 UI와 `Manic EMU` 표시 이름을 유지한다.

## 현재 완료 기준

1. 수정한 소스를 GitHub에 반영한다.
2. `Pocket 3DS IPA` 작업이 macOS에서 실제 기기용 앱을 빌드한다.
3. 성공한 실행에서 `Pocket3DS.ipa`를 받는다.
4. SideStore에서 설치하고 아이폰에서 실행을 확인한다.
5. JIT 활성화와 3DS 실행, 소리, 저장, 앱 복귀는 아이폰에서 각각 확인한다.

빌드가 성공했다는 사실만으로 JIT 또는 게임의 정상 구동을 주장하지 않는다.

## 폰에서 빌드 확인하기

- Safari에서 이 저장소의 **Actions → Pocket 3DS IPA**를 연다.
- Actions를 처음 사용하는 포크에서 활성화 안내가 나오면 해당 내용을
  확인하고 활성화한다. 이 계정 설정은 저장소 소유자가 해야 할 수 있다.
- `main`과 `codex/**` 브랜치의 코드가 바뀌면 빌드가 시작된다.
- 수동으로 실행할 때는 기본 브랜치에 작업 파일이 반영된 뒤
  **Run workflow**에서 원하는 브랜치를 고른다.
- 초록색으로 완료된 실행의 **Artifacts → pocket-3ds-ipa-실행번호**를 받는다.
  Safari에서 GitHub에 로그인되어 있어야 한다.
- 다운로드 파일이 ZIP이면 아이폰 **파일** 앱에서 압축을 풀고
  `Pocket3DS.ipa`를 선택한다. IPA 내부의 압축은 풀지 않는다.
- IPA는 저장 공간 사용을 줄이기 위해 **1일** 뒤 만료된다. 받은 IPA와
  아이폰에 설치한 앱은 이 보관 기간과 별개다. 설치한 앱에는 SideStore에
  표시되는 서명 만료일이 적용된다.

## SideStore에서 설치와 업데이트

- Wi-Fi와 LocalDevVPN을 연결하고 SideStore의 **My Apps → +**에서 IPA를 고른다.
- 첫 설치 후 앱 식별자는 `io.github.mindtrap110.pocket3ds`를 기반으로 한다.
  원본 Manic EMU와 별도 설치이므로 기존 게임 기록이 자동으로 이전되지는 않는다.
- 같은 Pocket 3DS 앱을 업데이트할 때는 기존 앱을 삭제하지 말고 새 IPA를
  설치한다. 기존 게임 저장 파일은 별도로 내보내 백업한다.
- 내장 JIT를 사용하려면 `JITEnabler` 확장 기능을 제거하지 않는다.
  필요한 디버그 권한 `get-task-allow`가 실제 설치에서도 유지되는지 확인한다.
- 무료 Apple 계정의 서명 갱신은 빌드와 별도 작업이다. 새 버전을 만들지
  않아도 SideStore에서 갱신할 수 있다. 자동 갱신의 성공 여부도 직접 확인한다.
- 이 개발용 IPA는 Apple 기기용 서명이 되어 있지 않다. Safari에서 받는
  것만으로 실행할 수 없으며 SideStore를 거쳐야 한다.

첫 버전의 서명 메타데이터는 디버그 권한만 요청한다. 원본의 iCloud·푸시·
특수 메모리 권한은 포함하지 않는다. 이 기능들을 쓰려면 별도 검증이 필요하다.

## 빌드 실패 시

빨간색 실행에서 `pocket-3ds-logs-실행번호`를 받거나 실패한 단계의 로그를
확인한다. 이 작업에는 패키지 해석 로그와 Xcode 빌드 로그가 포함된다.
실패한 실행의 링크를 개발 대화에 보내면 같은 소스 버전을 기준으로 조사한다.
Apple 비밀번호나 기기 페어링 파일을 저장소 또는 로그에 올리지 않는다.

## 빌드 환경

- macOS 26 표준 GitHub 실행 환경과 Xcode 26 이상을 사용한다.
- 추가 Apple 계정 로그인이나 인증서를 클라우드에 넣지 않고 빌드한다.
- 기존 `ManicEmuSideload` 스킴과 `SideloadRelease` 구성을 사용한다.
- Git LFS와 하위 저장소는 원본 커밋에 고정한다. 준비가 누락되면 빌드를
  중단하고 원인을 로그에 남긴다.
- `Scripts/ci/prepare_project.py`가 빌드용 사본의 앱/확장 식별자를 맞춘다.
  이때 생긴 Xcode 파일 변경을 다시 커밋하지 않는다.
- `Scripts/BuildSideloadIPA.sh`가 빌드, arm64 앱·3DS 코어·JIT 확장 확인,
  임시 서명과 IPA 패키징을 수행한다. 실제 폰 테스트 결과는 포함하지 않는다.

Linux에서 할 수 있는 검사는 다음과 같다.

```sh
python3 -m unittest discover -s Scripts/ci -p 'test_*.py'
bash -n Scripts/BuildSideloadIPA.sh
```

라이선스와 원본 프로젝트의 기여자 표시는 유지한다.
