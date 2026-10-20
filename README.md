# sonic-megadrive — reconstrução independente de pesquisa

Reconstrução **independente**, em Godot 4.7.2 + GDScript tipado, do comportamento de um único jogo de
Mega Drive (`Sonic The Hedgehog (USA, Europe).md`, ROM REV00 `GM 00001009-00`), com evidências rastreáveis.
Projeto de pesquisa **sem afiliação** com os detentores das marcas. O nome do aplicativo é
"Megadrive Platformer Lab" e o ID de pacote é provisório: `org.local.research.soniclike`.

> O arquivo `.md` é uma **ROM binária de Mega Drive** (big-endian, 68000), não Markdown.
> Ela é privada, somente leitura, e **nunca** entra em builds ou no git.

## Estado em uma frase

Física do personagem, câmera, anéis e monitor reproduzem a referência **quadro a quadro com tolerância zero**
em 5 replays de GHZ1 (até 900 quadros); as 19 fases são extraídas (privado) com validação 100% contra o VDP;
o app roda com título/menus/HUD/toque e exporta para os 5 destinos. **O jogo completo ainda não está
reconstruído** (inimigos, chefes, estágios especiais, final, música). Veja `docs/STATUS.md`.

## Uso (somente `make`)

```bash
make help
```

Fluxo típico:

```bash
make doctor
make bootstrap
make rom-analyze
make extract-data
make reference-traces
make test
make run
make build-supported
make verify-artifacts
make qa-matrix
```

- `make run` / `make run-fidelity` / `make run-enhanced`: abre o jogo. Com a ROM presente e `make extract-data`
  executado, as fases originais aparecem marcadas "(PRIVADO)" — apenas nesta máquina.
- Builds (`make build-macos|build-windows|build-web|build-android|build-ios`) contêm somente conteúdo próprio
  (fase "Lab Zone", arte e sons gerados em código).
- Android exige `ANDROID_HOME` (e JDK 17+); iOS exporta o projeto Xcode; IPA só com `IOS_TEAM_ID` + provisioning.

## Controles

| Ação | Teclado (padrão, remapeável) | Gamepad | Toque |
|---|---|---|---|
| Direcional | Setas / WASD | D-pad / analógico | Direcional virtual |
| A / B / C (todos saltam) | J/Z · K/X · L/C/Espaço | X · A · B | Botões A/B/C |
| Start (pausa) | Enter / Esc / P | Start | START |
| Depuração | F3 | — | — |

## Estrutura

```text
Makefile            interface única
tooling/            scripts Python (stdlib), lockfile de versões, interpretador 68000 próprio
game/               projeto Godot (src/, scenes/, data/, tests/, export_presets.cfg)
tests/              testes Python, replays de paridade, plataforma
docs/               documentação (pt-BR): engenharia reversa, gameplay, arquitetura, ADRs, plataformas, QA, segurança, operações
reports/            relatórios gerados (sem dados protegidos)
private/ work/ dist/  privado / temporários / artefatos (ignorados pelo git)
```

## Documentação

- Estado auditável: `docs/STATUS.md` · Continuação: `docs/operations/CONTINUE-CLAUDE.md`
- Engenharia reversa: `docs/reverse-engineering/` · Paridade: `reports/parity/summary.md`
- Plataformas: `docs/platforms/` · Matriz de builds: `docs/qa/build-matrix.md`
- Licenças e política de assets: `LICENSES.md`, `docs/security/distribuicao-assets.md`

## Pré-requisito inicial

GNU Make e Python 3. No Windows, instale GNU Make via MSYS2 (`docs/operations/onboarding.md`).
