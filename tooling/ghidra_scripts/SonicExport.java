// Post-script (Ghidra headless): exporta inventario de funcoes e listagem (somente para pasta privada).
import ghidra.app.script.GhidraScript;
import ghidra.program.model.listing.*;
import java.io.*;

public class SonicExport extends GhidraScript {
    @Override
    public void run() throws Exception {
        String[] args = getScriptArgs();
        String outDir = args.length > 0 ? args[0] : ".";
        Listing listing = currentProgram.getListing();
        try (PrintWriter f = new PrintWriter(new FileWriter(new File(outDir, "ghidra-functions.csv")))) {
            f.println("entry,name,body_bytes,instructions,callers,callees");
            FunctionIterator it = listing.getFunctions(true);
            while (it.hasNext()) {
                Function fn = it.next();
                long n = 0;
                InstructionIterator ii = listing.getInstructions(fn.getBody(), true);
                while (ii.hasNext()) { ii.next(); n++; }
                f.printf("0x%06X,%s,%d,%d,%d,%d%n", fn.getEntryPoint().getOffset(), fn.getName(),
                         fn.getBody().getNumAddresses(), n,
                         fn.getCallingFunctions(monitor).size(), fn.getCalledFunctions(monitor).size());
            }
        }
        long ninstr = 0;
        try (PrintWriter f = new PrintWriter(new FileWriter(new File(outDir, "ghidra-listing.txt")))) {
            InstructionIterator ii = listing.getInstructions(true);
            while (ii.hasNext()) {
                Instruction ins = ii.next();
                ninstr++;
                f.printf("%06X  %s%n", ins.getAddress().getOffset(), ins.toString());
            }
        }
        println("SonicExport: funcoes=" + listing.getFunctions(true).hashCode() + " instrucoes=" + ninstr);
    }
}
