# Regras gerais

- Anéis: +1; 100 e 200 dão vida extra (uma vez cada). Dano com anéis: perde todos (espalha até 32); sem anéis: morte. Escudo absorve um dano.
- Invulnerabilidade após dano: 120 quadros (pisca a cada 4); anéis só coletáveis após 30 quadros.
- Invencibilidade e tênis: 0x4B0 quadros (20 s).
- Tempo: 9:59 → time over (morte). Vidas iniciais: 3. Vida extra por pontuação a cada 50 000 em consoles não-japoneses (observado no código; não verificado por replay).
- Morte: queda até o limite inferior + 0x100; 60 quadros e reinício da fase; sem vidas → game over.
- Gerador pseudoaleatório: semente 0x2A6D365A quando zero; recorrência de 32 bits (implementada; não usada pelos objetos atuais).
- Bônus de fim de ato no app: tabela de tempo e anéis×100 — valores de tempo **INFERIDOS** (não medidos).
