# Web desktop
- `make build-web` exporta a Web **com as 19 fases** em `dist-private/web` (a ROM entra só durante a exportação). `make web-serve` publica essa pasta em http://127.0.0.1:8060/.
- `make build-web-public` gera `dist/web` só com a Lab Zone, sem a ROM. `make web-serve PUBLIC=1` serve essa pasta.
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

## Builds locais e a pasta pública
- `make build-web` (e macos, windows, android, ios) grava em `dist-private/` e inclui as 19 fases. A ROM só entra durante a exportação e sai de `game/private_pack/` em seguida. Uso pessoal: não compartilhar nem publicar em aberto.
- `make build-web-public` grava `dist/web` só com a Lab Zone. `make check-no-rom-in-dist` continua olhando `dist/` e `game/`, não `dist-private/`.
- Azure privada (as 19 fases): `make package-web-azure` gera `dist-private/web-azure.zip`. Publicar só com autenticação (Entra ID/Easy Auth) ou restrição por IP.

## Hospedagem na Azure
O texto "You do not have permission to view this directory or page." aparece quando o IIS não acha `index.html` na raiz de `wwwroot` (zip que contém a pasta `web/` em vez dos arquivos) ou quando o `web.config` quebra o site (500.19, mensagem genérica). Um `<remove>` de `.wasm` ou `.pck` que ainda não existe no mapa MIME do servidor causa esse 500.19. O `web.config` gerado só **adiciona** esses dois tipos e define `index.html` como documento padrão.

`make build-web` grava a Web com as 19 fases em `dist-private/web/` (`web.config` e `staticwebapp.config.json` inclusos).

Publicação: `make package-web-azure` gera `dist-private/web-azure.zip` com `index.html`, `index.js`, `index.wasm`, `index.pck` e `web.config` **na raiz do zip** (sem `index.embed.js`). Enviar esse zip (não um zip feito no Finder da pasta):
```bash
az webapp deploy --resource-group <grupo> --name <app> --src-path dist-private/web-azure.zip --type zip
```
O App Service precisa ser **Windows** para o `web.config` valer. No Linux ele é ignorado; use pilha Node e
`pm2 serve /home/site/wwwroot --no-daemon`.
Diagnóstico: `make web-azure-check URL=https://<app>.azurewebsites.net/` (raiz, `/index.html`, tipos MIME).
- Static Web Apps: pasta do app = conteúdo de `dist-private/web`, sem build (`skip_app_build: true`).
- `index.embed.js` (~53 MB) só é baixado por `file://`; fica de fora do zip.
- O zip privado contém o jogo e fica em `dist-private/`, fora do que `make check-no-rom-in-dist` varre. Não publicar em aberto.
Status: configuração gerada localmente; a implantação real na Azure não foi verificada por nós — registrar com
`make qa-record TARGET=web-azure STATUS=PASS|FAIL NOTES="..."`.
