# ADR 0002 — REA e provedores de análise
Status: aceito com bloqueio. REA 6.7.0 local, sempre sob `sandbox-exec`. Provider Ghidra falha sob sandbox
(`java spawn EPERM`); usuário negou execução fora do sandbox ⇒ análise profunda REA BLOQUEADA.
Alternativas adotadas: Ghidra headless em sandbox semeado com cobertura dinâmica; interpretador 68000 próprio.
Reabrir se: autorização explícita, nova versão do REA compatível com sandbox, ou provider alternativo.
