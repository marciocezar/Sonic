# Matriz de builds e testes (gerada por `make qa-matrix`)

Atualizada: 2026-10-18T22:59:31+00:00. Status: NOT_STARTED, BUILT_NOT_TESTED, PASS, FAIL, BLOCKED. PASS só com execução real registrada.

| Destino | Status | Quando | Comando | Artefatos (SHA-256) | Notas |
|---|---|---|---|---|---|
| macOS (.app/.zip) | **BUILT_NOT_TESTED** | 2026-10-18T22:49:42+00:00 | `make build-macos` | `dist/macos/MegadrivePlatformerLab.zip` 60,891,371 B `27ae940940493e38…` | exportado; teste em dispositivo/host pendente |
| Windows (.exe+.pck) | **BUILT_NOT_TESTED** | 2026-10-18T22:49:46+00:00 | `make build-windows` | `dist/windows/MegadrivePlatformerLab.exe` 109,268,480 B `d34d36f3be1a6c49…`<br>`dist/windows/MegadrivePlatformerLab.pck` 253,928 B `0e4bf17f85573f3a…` | exportado; teste em dispositivo/host pendente |
| Web desktop | **BUILT_NOT_TESTED** | 2026-10-18T22:58:17+00:00 | `make build-web` | `dist/web/index.apple-touch-icon.png` 9,365 B `fa65e6a0eef67f5a…`<br>`dist/web/index.audio.position.worklet.js` 2,973 B `be33985bc7160d6b…`<br>`dist/web/index.audio.worklet.js` 7,298 B `5b476a9c9ce642c0…` | exportado; teste em dispositivo/host pendente |
|   └ Web desktop (navegador real) | **PASS** | 2026-10-18T22:59:31+00:00 | `manual/qa-record` | - | Via HTTP: Chromium embutido sem erros. Modo file:// (dados embutidos) validado com servidor sem wasm/pck e ?embed=1: abre, entra na fase, console limpo. Abertura por file:// real pendente de confirmacao no navegador do usuario. |
|   └ Web iPhone (Safari iOS) | **BUILT_NOT_TESTED** | 2026-10-18T22:59:31+00:00 | `make web-mobile-check` | - | Verificação estrutural. Carga real em Safari iOS e Chrome Android, multitoque e áudio por gesto exigem aparelho físico: status BUILT_NOT_TESTED até sessão real. |
|   └ Web Android (Chrome) | **BUILT_NOT_TESTED** | 2026-10-18T22:59:31+00:00 | `make web-mobile-check` | - | Verificação estrutural. Carga real em Safari iOS e Chrome Android, multitoque e áudio por gesto exigem aparelho físico: status BUILT_NOT_TESTED até sessão real. |
| Android app (APK debug) | **BLOCKED** | 2026-10-18T22:49:50+00:00 | `` | - | ANDROID_HOME/ANDROID_SDK_ROOT não definido ou inválido (ver .env.example) |
| Android AAB (release) | **NOT_STARTED** | - | `-` | - |  |
| iOS (projeto Xcode) | **BUILT_NOT_TESTED** | 2026-10-18T22:49:56+00:00 | `make build-ios` | `dist/ios/MegadrivePlatformerLab.xcodeproj/project.pbxproj` 16,570 B `1430d705be2f90e7…`<br>`dist/ios/MegadrivePlatformerLab.pck` 253,976 B `b4557055e73f6b35…` | Team ID marcador 0000000000 (sem assinatura); IPA exige IOS_TEAM_ID real + provisioning. exportado; teste em dispositivo/host pendente |
|   └ iOS Simulator | **BLOCKED** | 2026-10-18T20:18:51+00:00 | `manual/qa-record` | - | Template oficial sem fatia arm64-simulator; iOS 27 Simulator nao executa x86_64. Uso de simuladores fora do workspace suspenso a pedido do usuario. |
|   └ iOS IPA assinado | **NOT_STARTED** | - | `-` | - |  |
