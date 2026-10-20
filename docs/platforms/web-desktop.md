# Web desktop
- `make build-web` → `dist/web/` (index.html, .js, .wasm, .pck, worklets de áudio). Build sem threads.
- `make web-serve` (http://127.0.0.1:8060), `make test-web` (smoke HTTP: 200 + `application/wasm`).
- Estado: **PASS** em navegador real (Chromium embutido no app Claude, macOS): carregamento WebGL2, menu e jogo por teclado.
- Áudio inicia após o primeiro gesto do usuário (política do navegador). Perda de foco libera teclas.
- Hospedagem: qualquer servidor HTTPS estático; não exige COOP/COEP.

## Abrir direto do disco (file://)
`dist/web/index.html` também abre por `file://` (duplo clique ou colando o caminho no navegador). Navegadores
bloqueiam `fetch`/`addModule` nesse modo; por isso o export gera `index.embed.js` (base64 de `index.wasm`,
`index.pck` e worklets de áudio, ~53 MB) e a página só o carrega quando aberta por `file://` (ou com `?embed=1`),
atendendo o carregador do Godot com os dados embutidos. Por HTTP nada muda (o arquivo não é baixado).
Validação: servidor de teste SEM `index.wasm`/`index.pck` + `?embed=1` no Chromium embutido → jogo abre e entra na fase,
console sem erros, só `index.embed.js` requisitado. Abertura real por `file://` no Safari/Chrome do usuário: registrar
com `make qa-record TARGET=web-desktop-file`.
Alternativa: `make web-serve OPEN=1`.

## Builds públicos x privados
- Público (`make build-<alvo>` → `dist/`): só código próprio + LAB ZONE. A opção "carregar ROM" foi removida (2026-10-18,
  pedido do usuário).
- Privado (`make build-private-<alvo>` / `make build-private-supported` → `dist-private/`): inclui o conteúdo do jogo
  (ROM REV00 do workspace, copiada para `game/private_pack/` só durante a exportação e apagada em seguida). Abre direto
  com todas as zonas no perfil Fidelity (visual original). **Uso pessoal: não compartilhar nem publicar.**
- Azure privada: publicar `dist-private/web` SOMENTE com autenticação do App Service ligada (Entra ID/Easy Auth) ou
  restrição de acesso por IP; sem isso o site fica público e expõe o conteúdo do jogo.

## Hospedagem na Azure
Erro "You do not have permission to view this directory or page." = o IIS não achou `index.html` na raiz do site
(arquivos publicados dentro de uma subpasta, ex.: `wwwroot/web/`) e/ou não conhece os tipos `.wasm`/`.pck`.
`make build-web` gera em `dist/web/`:
- `web.config` (App Service **Windows**/IIS): documento padrão `index.html`, listagem desligada, MIME `.wasm`
  (`application/wasm`), `.pck`, `.js`, `.json` e limite de requisição de 200 MB.
- `staticwebapp.config.json` (Azure **Static Web Apps**): fallback e tipos MIME.

Publicação: `make package-web-azure` gera `dist/web-azure.zip` com `index.html` e `web.config` **na raiz do zip**
(sem `index.embed.js`). Enviar esse zip por zip deploy (o conteúdo vai direto para `site/wwwroot`):
```bash
az webapp deploy --resource-group <grupo> --name <app> --src-path dist/web-azure.zip --type zip
```
Não publicar a pasta do projeto nem `dist/` (a extensão do VS Code pergunta a pasta: escolher `dist/web`).
Diagnóstico do site publicado: `make web-azure-check URL=https://<app>.azurewebsites.net/` (raiz, `/index.html`,
tipos MIME de `.wasm`/`.pck`/`.js`; aponta "index.html fora da raiz" ou "sem documento padrão"). Validado localmente
contra um servidor com a estrutura correta (PASS) e com a pasta `web/` aninhada (FAIL com o diagnóstico certo).
- App Service **Linux**: `web.config` é ignorado; usar pilha Node e comando de inicialização
  `pm2 serve /home/site/wwwroot --no-daemon` (ou preferir Static Web Apps).
- Static Web Apps: pasta do app = `dist/web`, sem build (`skip_app_build: true`).
- `index.embed.js` (~53 MB) só é baixado por `file://`; pode ser omitido no servidor.
- Nenhum dado da ROM está no build (`make check-no-rom-in-dist`); as zonas originais vêm do botão
  "CARREGAR ROM" no navegador de cada jogador (ver `docs/gameplay/progressao.md`).
Status: configuração gerada e validada localmente (servidor HTTP + Chromium); implantação real na Azure não
verificada por nós — registrar com `make qa-record TARGET=web-azure STATUS=PASS|FAIL NOTES="..."`.
