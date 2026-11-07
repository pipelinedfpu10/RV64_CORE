module immediate_generator (
    input  logic [31:0] instruction,
    output logic [63:0] immediate
);

    logic [6:0] opcode;

    always_comb begin
        opcode    = instruction[6:0];
        immediate = 64'd0;

        case (opcode)

            // ==========================================
            // I-TYPE
            // ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI
            // ADDIW, SLLIW, SRLIW, SRAIW
            // LOAD (LB,LH,LW,LD,LBU,LHU,LWU), FLW, JALR
            // ==========================================
            7'b0010011,
            7'b0011011,
            7'b0000011,
            7'b0000111,
            7'b1100111: begin
                immediate = {{52{instruction[31]}}, instruction[31:20]};
            end

            // ==========================================
            // S-TYPE
            // SB, SH, SW, SD, FSW
            // ==========================================
            7'b0100011,
            7'b0100111: begin
                immediate = {{52{instruction[31]}},
                             instruction[31:25],
                             instruction[11:7]};
            end

            // ==========================================
            // B-TYPE
            // BEQ, BNE, BLT, BGE, BLTU, BGEU
            // ==========================================
            7'b1100011: begin
                immediate = {{51{instruction[31]}},
                             instruction[31],
                             instruction[7],
                             instruction[30:25],
                             instruction[11:8],
                             1'b0};
            end

            // ==========================================
            // U-TYPE
            // LUI, AUIPC
            // (in RV64 the 32-bit result is sign extended to 64 bits)
            // ==========================================
            7'b0110111,
            7'b0010111: begin
                immediate = {{32{instruction[31]}},
                             instruction[31:12],
                             12'b0};
            end

            // ==========================================
            // J-TYPE
            // JAL
            // ==========================================
            7'b1101111: begin
                immediate = {{43{instruction[31]}},
                             instruction[31],
                             instruction[19:12],
                             instruction[20],
                             instruction[30:21],
                             1'b0};
            end

            default: begin
                immediate = 64'd0;
            end

        endcase
    end

endmodule


