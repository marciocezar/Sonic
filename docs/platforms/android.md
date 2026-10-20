# Android (app nativo)
- Requisitos: `ANDROID_HOME` (platform-tools + build-tools), JDK 17+ (`JAVA_HOME` ou detectado).
- `make build-android ANDROID_HOME=...` → `dist/android/MegadrivePlatformerLab-debug.apk` (arm64-v8a + x86_64,
  assinado com keystore de **depuração** local gerada em `work/keys/`).
- `make android-install DEVICE=serial`, `make test-android` (instala, inicia, captura tela) — exigem aparelho/emulador.
- `make build-android-aab`: exige template Gradle instalado e keystore de release via variáveis → **BLOCKED** hoje.
- Estado: **BUILT_NOT_TESTED** (APK estruturalmente válido; teste em emulador interrompido por decisão do usuário).
