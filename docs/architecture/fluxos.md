# Fluxos (Mermaid)

## Boot
```mermaid
sequenceDiagram
  participant OS
  participant Main as main.gd
  participant S as Settings
  participant C as LevelCatalog
  OS->>Main: _ready(args)
  Main->>S: carrega user://settings.cfg (schema 1)
  Main->>C: scan(builtin + levelpacks privados opcionais)
  Main->>Main: monta SubViewport + WorldView + Overlay + TouchLayer
  Main->>Main: estado "title" (ou --level)
```

## Entrada → simulação
```mermaid
flowchart LR
  K[Teclado/InputMap] --> R[InputRouter.read_bits]
  G[Gamepad + analógico] --> R
  T[TouchOverlay → TouchLogic.bits] --> R
  L[toques < 1 quadro retidos] --> R
  R -->|1 byte por quadro| SIM[GameSim.tick]
  FOCUS[perda de foco] -->|release_all| R
```

## Laço do jogo (tick fixo)
```mermaid
flowchart TD
  F[_process(delta)] --> A[acc += min(delta,0.25)]
  A --> W{acc >= 1/60 e passos < 4?}
  W -- sim --> T[sim.tick(bits)] --> E[AudioBus.handle_events] --> A2[acc -= 1/60] --> W
  W -- não --> D[WorldView/Overlay redesenham o estado atual]
```

## Persistência
`Settings.save_settings()` grava ConfigFile com seção `meta.schema=1`; schema diferente → padrões (sem migração destrutiva).

## Render
Perfil Fidelity: SubViewport 320×224, escala inteira, filtro nearest; arte da VRAM privada se houver, senão arte própria.
Perfil Enhanced: 640×448, filtro linear, arte própria, parallax procedural. Ambos leem o mesmo GameSim.

## Export
```mermaid
flowchart LR
  M[make build-X] --> GT[godot_tasks.export] --> GR[godot_refresh] --> GE[godot --export-*] --> SC[check-no-rom-in-dist] --> ST[(status.json BUILT_NOT_TESTED)]
  ST --> VA[make verify-artifacts] --> QA[make qa-matrix]
```
