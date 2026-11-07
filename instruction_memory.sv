module instruction_memory (
    input  logic [63:0] address,
    output logic [31:0] instruction
);

    // RV64 instructions are still 32 bits wide
    logic [31:0] memory [0:255];
    integer i;

    // Initialize memory and load instructions from the hex file
    initial begin
        // Default all memory locations to NOP (addi x0,x0,0)
        for (i = 0; i < 256; i = i + 1) begin
            memory[i] = 32'h00000013;
        end

        // Load machine-code instructions from test.hex
        $readmemh("test.hex", memory);
    end

    // Instruction fetch: PC bits [9:2] select a word
    always_comb begin
        instruction = memory[address[9:2]];
    end

endmodule


