// Pre-script (Ghidra headless): marca vetores 68000 como pontos de entrada antes da auto-analise.
// Escrito para o projeto sonic-megadrive; nao contem codigo do jogo.
import ghidra.app.script.GhidraScript;
import ghidra.program.model.address.Address;
import ghidra.program.model.symbol.SourceType;

public class SonicSeedEntries extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] names = {"initial_ssp","reset","bus_error","address_error","illegal","zero_divide","chk","trapv",
                          "privilege","trace","line_a","line_f"};
        for (int i = 1; i < 64; i++) {
            Address va = toAddr(i * 4);
            long target = getInt(va) & 0xffffffffL;
            createDWord(va);
            if (target >= 0x200 && target < 0x80000 && (target & 1) == 0) {
                Address t = toAddr(target);
                String n = i < names.length ? names[i] : (i == 28 ? "hblank_irq4" : (i == 30 ? "vblank_irq6" : "vector_" + i));
                if (getSymbolAt(t) == null) createLabel(t, n, true, SourceType.ANALYSIS);
                addEntryPoint(t);
                disassemble(t);
                if (getFunctionAt(t) == null) createFunction(t, null);
            }
        }
        String[] args = getScriptArgs();
        int seeded = 0;
        if (args.length > 0) {
            java.io.File f = new java.io.File(args[0]);
            if (f.isFile()) {
                for (String line : java.nio.file.Files.readAllLines(f.toPath())) {
                    line = line.trim();
                    if (line.isEmpty()) continue;
                    Address a = toAddr(Long.parseLong(line, 16));
                    if (getInstructionAt(a) == null) { disassemble(a); seeded++; }
                }
            }
        }
        println("SonicSeedEntries: vetores semeados; PCs de cobertura desmontados: " + seeded);
    }
}
