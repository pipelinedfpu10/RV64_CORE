module control_unit (
    input  logic [6:0] opcode,
    input  logic [2:0] funct3,
    input  logic [6:0] funct7,

    output logic       reg_write,       // write integer register
    output logic       alu_src,         // 0 = rs2, 1 = immediate
    output logic [3:0] alu_control,
    output logic       mem_read,
    output logic       mem_write,
    output logic       mem_to_reg,
    output logic       lui,
    output logic       auipc,
    output logic       jal,
    output logic       jalr,
    output logic       branch,
    output logic       is_word,         // W instructions (32-bit operation)
    output logic       mul_en,          // MUL / MULW
    output logic       fp_en,           // FADD.S / FSUB.S / FMUL.S
    output logic [1:0] fp_op,           // 00 = FADD, 01 = FSUB, 10 = FMUL
    output logic       fp_load,         // FLW
    output logic       fp_store,        // FSW
    output logic       fp_reg_write     // write floating point register
);

    always_comb begin

        reg_write    = 1'b0;
        alu_src      = 1'b0;
        alu_control  = 4'b0000;
        mem_read     = 1'b0;
        mem_write    = 1'b0;
        mem_to_reg   = 1'b0;
        lui          = 1'b0;
        auipc        = 1'b0;
        jal          = 1'b0;
        jalr         = 1'b0;
        branch       = 1'b0;
        is_word      = 1'b0;
        mul_en       = 1'b0;
        fp_en        = 1'b0;
        fp_op        = 2'b00;
        fp_load      = 1'b0;
        fp_store     = 1'b0;
        fp_reg_write = 1'b0;

        case (opcode)

            // ==========================================
            // I-TYPE (64-bit)
            // ==========================================
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                case (funct3)
                    3'b000: alu_control = 4'b0000;   // ADDI
                    3'b001: alu_control = 4'b0101;   // SLLI
                    3'b010: alu_control = 4'b0110;   // SLTI
                    3'b011: alu_control = 4'b0111;   // SLTIU
                    3'b100: alu_control = 4'b0100;   // XORI
                    3'b101: begin
                        if (funct7[5] == 1'b0)
                            alu_control = 4'b1000;   // SRLI
                        else
                            alu_control = 4'b1001;   // SRAI
                    end
                    3'b110: alu_control = 4'b0011;   // ORI
                    3'b111: alu_control = 4'b0010;   // ANDI
                    default: alu_control = 4'b0000;
                endcase
            end

            // ==========================================
            // I-TYPE (32-bit)  ADDIW, SLLIW, SRLIW, SRAIW
            // ==========================================
            7'b0011011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                is_word   = 1'b1;
                case (funct3)
                    3'b000: alu_control = 4'b0000;   // ADDIW
                    3'b001: alu_control = 4'b0101;   // SLLIW
                    3'b101: begin
                        if (funct7[5] == 1'b0)
                            alu_control = 4'b1000;   // SRLIW
                        else
                            alu_control = 4'b1001;   // SRAIW
                    end
                    default: reg_write = 1'b0;
                endcase
            end

            // ==========================================
            // R-TYPE (64-bit) + MUL
            // ==========================================
            7'b0110011: begin
                if (funct7 == 7'b0000001) begin
                    // M extension: MUL, MULH, MULHSU, MULHU (funct3 = 000..011)
                    // DIV / REM (funct3 = 100..111) are not supported
                    if (funct3[2] == 1'b0) begin
                        reg_write = 1'b1;
                        mul_en    = 1'b1;
                    end
                end
                else begin
                    reg_write = 1'b1;
                    alu_src   = 1'b0;
                    case (funct3)
                        3'b000: begin
                            if (funct7[5] == 1'b1)
                                alu_control = 4'b0001;   // SUB
                            else
                                alu_control = 4'b0000;   // ADD
                        end
                        3'b001: alu_control = 4'b0101;   // SLL
                        3'b010: alu_control = 4'b0110;   // SLT
                        3'b011: alu_control = 4'b0111;   // SLTU
                        3'b100: alu_control = 4'b0100;   // XOR
                        3'b101: begin
                            if (funct7[5] == 1'b1)
                                alu_control = 4'b1001;   // SRA
                            else
                                alu_control = 4'b1000;   // SRL
                        end
                        3'b110: alu_control = 4'b0011;   // OR
                        3'b111: alu_control = 4'b0010;   // AND
                        default: alu_control = 4'b0000;
                    endcase
                end
            end

            // ==========================================
            // R-TYPE (32-bit)  ADDW, SUBW, SLLW, SRLW, SRAW + MULW
            // ==========================================
            7'b0111011: begin
                is_word = 1'b1;
                if (funct7 == 7'b0000001) begin
                    // M extension: only MULW is supported
                    if (funct3 == 3'b000) begin
                        reg_write = 1'b1;
                        mul_en    = 1'b1;
                    end
                end
                else begin
                    reg_write = 1'b1;
                    case (funct3)
                        3'b000: begin
                            if (funct7[5] == 1'b1)
                                alu_control = 4'b0001;   // SUBW
                            else
                                alu_control = 4'b0000;   // ADDW
                        end
                        3'b001: alu_control = 4'b0101;   // SLLW
                        3'b101: begin
                            if (funct7[5] == 1'b1)
                                alu_control = 4'b1001;   // SRAW
                            else
                                alu_control = 4'b1000;   // SRLW
                        end
                        default: reg_write = 1'b0;
                    endcase
                end
            end

            // ==========================================
            // LOAD  (LB, LH, LW, LD, LBU, LHU, LWU)
            // ==========================================
            7'b0000011: begin
                reg_write   = 1'b1;
                alu_src     = 1'b1;
                alu_control = 4'b0000;
                mem_read    = 1'b1;
                mem_to_reg  = 1'b1;
            end

            // ==========================================
            // STORE (SB, SH, SW, SD)
            // ==========================================
            7'b0100011: begin
                alu_src     = 1'b1;
                alu_control = 4'b0000;
                mem_write   = 1'b1;
            end

            // ==========================================
            // BRANCH
            // ==========================================
            7'b1100011: begin
                branch = 1'b1;
            end

            // ==========================================
            // LUI
            // ==========================================
            7'b0110111: begin
                lui       = 1'b1;
                reg_write = 1'b1;
            end

            // ==========================================
            // AUIPC
            // ==========================================
            7'b0010111: begin
                auipc     = 1'b1;
                reg_write = 1'b1;
            end

            // ==========================================
            // JAL
            // ==========================================
            7'b1101111: begin
                jal       = 1'b1;
                reg_write = 1'b1;
            end

            // ==========================================
            // JALR
            // ==========================================
            7'b1100111: begin
                jalr      = 1'b1;
                reg_write = 1'b1;
                alu_src   = 1'b1;
            end

            // ==========================================
            // FLW  (load word into floating point register)
            // ==========================================
            7'b0000111: begin
                alu_src      = 1'b1;
                alu_control  = 4'b0000;
                mem_read     = 1'b1;
                mem_to_reg   = 1'b1;
                fp_load      = 1'b1;
                fp_reg_write = 1'b1;
            end

            // ==========================================
            // FSW  (store word from floating point register)
            // ==========================================
            7'b0100111: begin
                alu_src     = 1'b1;
                alu_control = 4'b0000;
                mem_write   = 1'b1;
                fp_store    = 1'b1;
            end

            // ==========================================
            // FP ARITHMETIC: FADD.S, FSUB.S, FMUL.S
            // ==========================================
            7'b1010011: begin
                case (funct7)
                    7'b0000000: begin   // FADD.S
                        fp_en        = 1'b1;
                        fp_op        = 2'b00;
                        fp_reg_write = 1'b1;
                    end
                    7'b0000100: begin   // FSUB.S
                        fp_en        = 1'b1;
                        fp_op        = 2'b01;
                        fp_reg_write = 1'b1;
                    end
                    7'b0001000: begin   // FMUL.S
                        fp_en        = 1'b1;
                        fp_op        = 2'b10;
                        fp_reg_write = 1'b1;
                    end
                    default: begin
                    end
                endcase
            end

            default: begin
            end

        endcase
    end

endmodule


