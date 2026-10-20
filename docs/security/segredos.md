# Segredos
- Nenhum segredo no repositório. `.env.example` contém apenas valores fictícios; `.env` é ignorado e não é lido automaticamente.
- Keystore de depuração Android (credenciais públicas padrão) é gerada em `work/keys/` e ignorada.
- Release Android: variáveis `GODOT_ANDROID_KEYSTORE_RELEASE_*` fornecidas pelo shell/gerenciador de segredos.
- iOS: certificados permanecem no keychain do usuário; apenas Team ID/UUID de perfil por variável.
