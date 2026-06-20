# Samsung Charge Guard

[English README](README.md)

Samsung Charge Guard는 루팅된 삼성 갤럭시에서 충전 상한을 제한하면서, Wi-Fi/SSH 연결이 끊기지 않도록 설계한 작은 루트 스크립트입니다.

Termux SSH 서버를 계속 켜두고, 화면이 꺼져도 Wi-Fi 연결이 유지되어야 하는 환경을 기준으로 만들었습니다.

## 동작 방식

기본 정책:

- **80% 이상**: `store_mode=1`로 충전 차단
- **78% 이하**: `store_mode=0`으로 충전 허용
- 항상 `batt_slate_mode=0` 유지
- 선택적으로 Wi-Fi 절전 해제:
  - `cmd wifi force-low-latency-mode enabled`
  - `iw dev <iface> set power_save off`

## 왜 `store_mode`를 쓰나?

삼성 커널에는 여러 충전 제어 노드가 있습니다. 일부 충전 제한 앱은 `batt_slate_mode=1`을 사용하지만, 특정 기기에서는 이 값 때문에 Android가 외부 전원이 끊긴 것처럼 인식할 수 있습니다.

```text
mIsPowered=false
mPlugType=0
status=Discharging
```

이 상태가 되면 화면 꺼짐 시 Wi-Fi suspend / power save가 강하게 걸려서 SSH 세션이 끊길 수 있습니다.

이 프로젝트는 의도적으로 `batt_slate_mode=1`을 사용하지 않습니다. 대신 아래 노드를 사용합니다.

```text
/sys/class/power_supply/battery/store_mode
```

그리고 항상 아래 값을 유지합니다.

```text
/sys/class/power_supply/battery/batt_slate_mode = 0
```

테스트한 삼성 기기에서는 `store_mode=1` 상태에서 충전은 멈추지만 Android는 외부 전원을 계속 인식했습니다.

```text
status=Discharging
store_mode=1
batt_slate_mode=0
mIsPowered=true
mPlugType=1
current_now=0
```

## 중요한 동작 차이

`store_mode=1` 상태에서는 폰이 외부 전원으로 계속 동작할 수 있습니다. 그래서 배터리가 자동으로 78%까지 빠지지 않고, 현재 퍼센트 근처에서 유지될 수 있습니다.

예시:

- 88%에서 시작하면 88% 근처에 머무를 수 있습니다.
- 먼저 충전기를 뽑고 70%까지 방전한 뒤 다시 꽂으면, 약 80%까지 충전되고 그 근처에서 멈춥니다.

즉 이 스크립트는 강제로 78~80% 사이를 계속 오가는 방식이 아니라, **Wi-Fi/SSH 안정성을 우선하는 80% 상한 유지 방식**입니다.

## 필요 조건

- 루트 권한
- Magisk의 `/data/adb/service.d` 부팅 스크립트 지원
- 삼성 커널에 아래 노드가 있어야 함:
  - `/sys/class/power_supply/battery/store_mode`
  - `/sys/class/power_supply/battery/batt_slate_mode`
- 선택 권장:
  - `/system/bin/iw`, `/vendor/bin/iw`, 또는 Termux의 `iw`

## 설치

Termux 또는 다른 셸에서:

```sh
unzip samsung-charge-guard.zip
cd samsung-charge-guard
su -c "sh $(pwd)/scripts/install.sh"
```

상태 확인:

```sh
su -c '/data/adb/samsung-charge-guard.sh status'
```

로그 확인:

```sh
su -c 'tail -f /data/local/tmp/samsung-charge-guard.log'
```

## 설정

설치하면 아래 설정 파일이 생성됩니다.

```text
/data/adb/samsung-charge-guard.conf
```

기본값:

```sh
START=78
STOP=80
INTERVAL=60
BOOT_DELAY=60
WIFI_GUARD=1
STOP_BCL=1
```

수정:

```sh
su -c 'vi /data/adb/samsung-charge-guard.conf'
```

재시작:

```sh
su -c 'pkill -f samsung-charge-guard.sh'
su -c 'BOOT_DELAY=0 /data/adb/samsung-charge-guard.sh >/data/local/tmp/samsung-charge-guard.service.log 2>&1 &'
```

## 명령어

한 번만 정책 적용:

```sh
su -c '/data/adb/samsung-charge-guard.sh once'
```

상태 확인:

```sh
su -c '/data/adb/samsung-charge-guard.sh status'
```

충전 노드 초기화:

```sh
su -c '/data/adb/samsung-charge-guard.sh reset'
```

제거:

```sh
su -c "sh $(pwd)/scripts/uninstall.sh"
```

## Battery Charge Limiter 관련

MuntashirAkon의 BatteryChargeLimiter와 동시에 사용하지 않는 것을 권장합니다. 둘이 같은 sysfs 노드를 서로 다르게 제어할 수 있습니다.

기본 설정에서는 시작 시 해당 패키지를 force-stop합니다.

```sh
STOP_BCL=1
```

이 동작이 싫으면 설정 파일에서 `STOP_BCL=0`으로 바꾸세요.

## 안전 주의

이 스크립트는 `/sys/class/power_supply`에 값을 씁니다. 기기/커널에 따라 동작이 다를 수 있습니다.

상시 사용 전에는 반드시 연결 상태에서 아래를 확인하세요.

```sh
su -c '/data/adb/samsung-charge-guard.sh status'
```

80% 이상에서 목표 상태:

```text
store_mode=1
batt_slate_mode=0
mIsPowered=true
mPlugType=1
Wi-Fi power save: off
```

## 프로젝트 구조

```text
samsung-charge-guard/
├── README.md
├── README_KO.md
├── LICENSE
├── docs/
│   └── samsung-power-nodes.md
└── scripts/
    ├── install.sh
    ├── samsung-charge-guard.sh
    ├── status.sh
    └── uninstall.sh
```

## 라이선스

MIT
