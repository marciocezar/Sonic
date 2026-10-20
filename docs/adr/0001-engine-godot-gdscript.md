# ADR 0001 — Godot 4.7.2 estável + GDScript tipado
Status: aceito. Contexto: 5 destinos, Web incluída; Godot 4 C# tem limitações publicadas na Web.
Decisão: Godot 4.7.2-stable (fixado em `tooling/versions.lock`, SHA-512 verificado), GDScript tipado, renderer
Compatibility. Física/colisão próprias em inteiros (não `CharacterBody2D`). Consequências: exportações nativas
oficiais; necessidade de cuidado com tipagem (avisos de inferência de Variant tratados como erro).
