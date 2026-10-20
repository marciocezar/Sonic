# iOS (app nativo)
- `make build-ios` → projeto Xcode em `dist/ios/` (exportado com Team ID marcador `0000000000` se `IOS_TEAM_ID` ausente).
- `make ios-xcode`: compila para o Simulator sem assinatura (x86_64, pois o template oficial 4.7.2 só traz fatia
  de Simulator x86_64 — verificado com `lipo`). **BUILD SUCCEEDED**.
- `make test-ios`: o Simulator do iOS 27 recusa apps x86_64 ⇒ **BLOCKED** (precisa template com arm64-simulator ou aparelho).
  Uso de Simuladores também suspenso por decisão do usuário.
- `make ios-archive`: requer `IOS_TEAM_ID` + `IOS_PROVISIONING_UUID` e certificado no keychain ⇒ **BLOCKED**. Nenhum IPA é simulado.
