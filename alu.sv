module alu (
    input  logic [63:0] a,
    input  logic [63:0] b,
    input  logic [3:0]  alu_control,
    input  logic        is_word,      // 1 = ADDW/SUBW/SLLW/SRLW/SRAW/ADDIW... (32-bit operation)
    output logic [63:0] result,
    output logic        zero
);

    logic [63:0] result64;
    logic [31:0] result32;

    //------------------------------------------------
    // 64-bit operations
    //------------------------------------------------
    always_comb begin
        case (alu_control)
            4'b0000: result64 = a + b;                                   // ADD
            4'b0001: result64 = a - b;                                   // SUB
            4'b0010: result64 = a & b;                                   // AND
            4'b0011: result64 = a | b;                                   // OR
            4'b0100: result64 = a ^ b;                                   // XOR
            4'b0101: result64 = a << b[5:0];                             // SLL
            4'b0110: result64 = ($signed(a) < $signed(b)) ? 64'd1 : 64'd0; // SLT
            4'b0111: result64 = (a < b) ? 64'd1 : 64'd0;                 // SLTU
            4'b1000: result64 = a >> b[5:0];                             // SRL
            4'b1001: result64 = $signed(a) >>> b[5:0];                   // SRA
            default: result64 = 64'b0;
        endcase
    end

    //------------------------------------------------
    // 32-bit operations (W instructions)
    //------------------------------------------------
    always_comb begin
        case (alu_control)
            4'b0000: result32 = a[31:0] + b[31:0];                       // ADDW
            4'b0001: result32 = a[31:0] - b[31:0];                       // SUBW
            4'b0101: result32 = a[31:0] << b[4:0];                       // SLLW
            4'b1000: result32 = a[31:0] >> b[4:0];                       // SRLW
            4'b1001: result32 = $signed(a[31:0]) >>> b[4:0];             // SRAW
            default: result32 = 32'b0;
        endcase
    end

    //------------------------------------------------
    // Result select: W results are sign extended to 64 bits
    //------------------------------------------------
    always_comb begin
        if (is_word)
            result = {{32{result32[31]}}, result32};
        else
            result = result64;
    end

    //------------------------------------------------
    // Zero Flag
    //------------------------------------------------
    always_comb begin
        if (result == 64'b0)
            zero = 1'b1;
        else
            zero = 1'b0;
    end

endmodule


