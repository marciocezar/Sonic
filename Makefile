# Makefile — interface única do projeto sonic-megadrive (um único jogo).
# Requer GNU Make (>= 3.81) e Python 3 (stdlib). Em Windows: GNU Make via MSYS2.
# Todas as receitas chamam Python de forma portável; nada de rm/sed/grep/find.

PYTHON ?= python3
T      := tooling
PY     := $(PYTHON) -I -B
# Variáveis de usuário (não secretas):
PROFILE   ?= fidelity      # fidelity | enhanced
COMPONENTS ?=              # bootstrap: godot templates rea ghidra (vazio = todos)
PORT      ?= 8060
DEVICE    ?=
REPLAY    ?=

.DEFAULT_GOAL := help
.PHONY: help doctor security-check bootstrap rea-check rea-analyze reverse-report assets-check \
        test test-unit test-parity test-touch lint format-check run run-fidelity run-enhanced \
        build-macos build-windows build-web build-web-public web-serve web-mobile-check build-android android-install \
        build-android-aab build-ios ios-xcode ios-archive test-web test-android test-ios \
        build-supported build-all verify-artifacts check-no-rom-in-dist qa-matrix docs sbom \
        license-audit package-check clean rom-analyze ghidra-analyze extract-data reference-traces demo-level qa-record test-macos bench bot-replay listing anim-dump parity-diag slot-diff rom-import-check rom-assets-check test-progression package-web-azure web-azure-check build-private-macos build-private-windows build-private-web build-private-android build-private-ios build-private-supported sprite-check

help: ## Lista os alvos disponíveis
	@$(PY) $(T)/mk.py help

doctor: ## Diagnostica pré-requisitos por SO (Godot, templates, SDKs, Xcode, REA)
	@$(PY) $(T)/doctor.py

security-check: ## Escopo, .gitignore, ausência de segredos/ROM em locais públicos
	@$(PY) $(T)/security_check.py

bootstrap: ## Instala dependências SOMENTE em tooling/ (COMPONENTS=godot templates rea ghidra)
	@$(PY) $(T)/bootstrap.py $(COMPONENTS)

rea-check: ## Verifica REA instalado localmente e providers disponíveis
	@$(PY) $(T)/rea_tools.py check

rom-analyze: ## Análise estática própria da ROM (cabeçalho, vetores, checksum, mapa)
	@$(PY) $(T)/rom_analyze.py

ghidra-analyze: ## Importa a ROM no Ghidra headless (68000) em work/, exporta funções
	@$(PY) $(T)/rea_tools.py ghidra

rea-analyze: rom-analyze ## Análise do único arquivo deste jogo via REA + ferramentas complementares
	@$(PY) $(T)/rea_tools.py analyze

extract-data: rom-analyze ## Extrai dados de jogo (privado) e gera parâmetros derivados
	@$(PY) $(T)/extract_data.py

reference-traces: ## Gera traces de referência por quadro (privado) a partir de tests/parity/replays (REPLAY=nome)
	@$(PY) $(T)/reference_trace.py $(REPLAY)

bot-replay: ## Gera replay por bot na referência (LEVEL=ghz1 FRAMES=3000 [POKE=quadro:x:y NAME=sufixo])
	@$(PY) $(T)/autoplay_bot.py $(or $(LEVEL),ghz1) $(or $(FRAMES),3000) "$(POKE)" "$(NAME)"

demo-level: ## Gera as fases próprias (game/data/levels/lab1.json e lab2.json)
	@$(PY) $(T)/gen_demo_level.py

parity-diag: ## Mostra o contexto da 1ª divergência de um replay (REPLAY=nome)
	@$(PY) $(T)/parity_diag.py $(REPLAY)

slot-diff: ## 1º quadro com ocupação de slots diferente da referência (REPLAY=nome)
	@$(PY) $(T)/slot_diff.py $(REPLAY)

listing: ## Mostra trecho da listagem Ghidra privada (FROM=0x.. TO=0x..)
	@$(PY) $(T)/listing.py $(FROM) $(TO)

anim-dump: ## Decodifica tabela de animação da ROM (ADDR=0x..; diagnóstico local)
	@$(PY) $(T)/anim_dump.py $(ADDR)

rom-import-check: ## Valida o importador de fases a partir da ROM (Python e GDScript) contra a extração por emulação
	@$(PY) $(T)/rom_levels.py
	@$(PY) $(T)/test_runner.py rom

rom-assets-check: ## Valida arte/blocos/paletas decodificados da ROM (Nemesis/Enigma/PLC) contra a VRAM capturada
	@$(PY) $(T)/rom_assets.py
	@$(PY) $(T)/test_runner.py rom

test-progression: ## Percorre as 19 fases em sequência carregadas da ROM do usuário (sem levelpacks)
	@$(PY) $(T)/test_runner.py progression

reverse-report: ## Compila evidências e hipóteses em reports/analysis
	@$(PY) $(T)/reverse_report.py

assets-check: ## Audita assets do projeto (licença/proveniência)
	@$(PY) $(T)/assets_check.py

test: test-unit test-parity test-touch ## Todos os testes

test-unit: ## Testes unitários (Python + GDScript headless)
	@$(PY) $(T)/test_runner.py unit

sprite-check: ## Confere quadro/espelhamento/arte/mapeamento do sprite de cada objeto contra a referência (após test-parity)
	@$(PY) $(T)/sprite_check.py

test-parity: ## Replays determinísticos vs referência medida (REPLAY=nome opcional)
	@$(PY) $(T)/parity.py $(REPLAY)

test-touch: ## Testes do adaptador touch/multitouch (headless)
	@$(PY) $(T)/test_runner.py touch

bench: ## Mede custo da simulação por tick (headless, host atual)
	@$(PY) $(T)/test_runner.py bench

lint: ## Lint de Python e GDScript
	@$(PY) $(T)/lint.py lint

format-check: ## Verifica formatação (tabs/espaços, EOL, trailing spaces)
	@$(PY) $(T)/lint.py format

run: ## Abre o jogo nativo no host (PROFILE=fidelity|enhanced)
	@$(PY) $(T)/godot_tasks.py run $(strip $(PROFILE))

run-fidelity: ## Abre o jogo no perfil Fidelity
	@$(PY) $(T)/godot_tasks.py run fidelity

run-enhanced: ## Abre o jogo no perfil Enhanced
	@$(PY) $(T)/godot_tasks.py run enhanced

build-macos: ## Exporta macOS com as 19 fases (dist-private/; uso pessoal, igual ao jogo nativo)
	@$(PY) $(T)/godot_tasks.py export-private macos

build-windows: ## Exporta Windows com as 19 fases (dist-private/; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private windows

build-web: ## Exporta Web com as 19 fases (dist-private/web; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private web

web-serve: ## Serve a Web jogável com as 19 fases (PORT=8060; PUBLIC=1 serve dist/web, só Lab Zone)
	@$(PY) $(T)/web_serve.py $(PORT) $(if $(LAN),--lan,) $(if $(OPEN),--open,) $(if $(PUBLIC),,--private)

build-web-public: ## Web sem as fases originais, em dist/web (só Lab Zone, sem a ROM)
	@$(PY) $(T)/godot_tasks.py export web

build-private-macos: ## Build PRIVADO macos em dist-private/ (conteúdo do jogo embutido; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private macos

build-private-windows: ## Build PRIVADO windows em dist-private/ (conteúdo do jogo embutido; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private windows

build-private-web: ## Build PRIVADO web em dist-private/ (conteúdo do jogo embutido; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private web

build-private-android: ## Build PRIVADO android em dist-private/ (conteúdo do jogo embutido; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private android

build-private-ios: ## Build PRIVADO ios em dist-private/ (conteúdo do jogo embutido; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private ios


build-private-supported: ## Builds PRIVADOS dos 5 destinos em dist-private/ (conteúdo do jogo embutido; nunca publicar)
	@$(PY) $(T)/godot_tasks.py build-private-supported

package-web-azure: ## Gera dist-private/web-azure.zip (19 fases, index.html na raiz) para um site Azure privado
	@$(PY) $(T)/godot_tasks.py package-web-azure

web-azure-check: ## Diagnostica o site publicado (URL=https://<app>.azurewebsites.net/)
	@$(PY) $(T)/godot_tasks.py web-azure-check $(URL)

web-mobile-check: ## Checa build Web para navegadores mobile (estrutura, threads, touch, viewport)
	@$(PY) $(T)/godot_tasks.py web-mobile-check

build-android: ## Exporta APK debug com as 19 fases (dist-private/; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private android

android-install: ## Instala APK em aparelho/emulador via adb (DEVICE=serial)
	@$(PY) $(T)/godot_tasks.py android-install $(DEVICE)

build-android-aab: ## Exporta AAB release (exige keystore de release via env)
	@$(PY) $(T)/godot_tasks.py export android-aab

build-ios: ## Exporta projeto Xcode com as 19 fases (dist-private/; uso pessoal)
	@$(PY) $(T)/godot_tasks.py export-private ios

ios-xcode: build-ios ## Compila o projeto Xcode exportado para o Simulator (sem assinatura)
	@$(PY) $(T)/godot_tasks.py ios-xcode

ios-archive: ## Archive/IPA — somente com Team ID e provisioning válidos
	@$(PY) $(T)/godot_tasks.py ios-archive

test-macos: ## Executa o .app exportado (fumaça com replay e captura de tela)
	@$(PY) $(T)/godot_tasks.py test-macos

test-web: ## Smoke test: serve dist/web e valida carregamento HTTP
	@$(PY) $(T)/godot_tasks.py test-web

test-android: ## Smoke test Android (adb/emulador)
	@$(PY) $(T)/godot_tasks.py test-android $(DEVICE)

test-ios: ## Smoke test iOS (Simulator)
	@$(PY) $(T)/godot_tasks.py test-ios

build-supported: ## Exporta os destinos possíveis e lista BLOCKED
	@$(PY) $(T)/godot_tasks.py build-supported

build-all: ## Exporta os 5 destinos; FALHA se algum não puder ser produzido
	@$(PY) $(T)/godot_tasks.py build-all

verify-artifacts: ## Verifica formato/estrutura/hash dos artefatos em dist/
	@$(PY) $(T)/verify_artifacts.py

check-no-rom-in-dist: ## Garante que ROM/conteúdo privado não estão em dist/ nem no projeto
	@$(PY) $(T)/security_check.py no-rom-in-dist

qa-record: ## Registra resultado de teste real (TARGET=, STATUS=, NOTES=)
	@$(PY) $(T)/qa_record.py "$(TARGET)" "$(STATUS)" "$(NOTES)"

qa-matrix: ## Gera docs/qa/build-matrix.md e matriz de mecânicas
	@$(PY) $(T)/qa_matrix.py

docs: ## Valida documentação obrigatória e links
	@$(PY) $(T)/docs_check.py

sbom: ## Gera SBOM (reports/qa/sbom.json)
	@$(PY) $(T)/sbom.py sbom

license-audit: ## Auditoria de licenças de dependências e assets
	@$(PY) $(T)/sbom.py licenses

package-check: ## Checa metadados de pacote (ID provisório, sem afiliação oficial)
	@$(PY) $(T)/sbom.py package

clean: ## Remove somente temporários conhecidos em work/ e dist/
	@$(PY) $(T)/clean.py
