# Câmera (`game/src/camera/camera_state.gd`) — VERIFIED (camx/camy/look idênticos nos replays)
- Horizontal: janela 144–160 px da borda esquerda; à frente avança no máx. 16 px/quadro; atrás segue sem limite; respeita limites esquerdo/direito.
- Vertical: alvo = look_shift (0x60). No chão: velocidade 6 px/quadro (16 se |gs| ≥ 0x800); olhando: 2 px. No ar: janela de 64 px, 16 px/quadro.
- Movimento "exato" zera a fração; movimento limitado acumula subpixel. Fases com laço vertical aplicam máscara 0x7FF.
- Olhar para cima/baixo: look_shift até 0xC8 / 0x08 em passos de 2; retorna a 0x60.
- Limite inferior dinâmico: alvo por eventos da fase, aproximado a 2 px/quadro (8 no ar perto do limite).
