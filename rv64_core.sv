module rv64_core (
    input  logic        clk,
    input  logic        reset,

    output logic [63:0] pc,
    output logic [31:0] instruction,
    output logic [6:0]  opcode,
    output logic [4:0]  rd,
    output logic [2:0]  funct3,
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [6:0]  funct7,
    output logic [63:0] read_data1,
    output logic [63:0] read_data2,
    output logic [63:0] immediate,
    output logic [63:0] alu_result,
    output logic [3:0]  alu_control,
    output logic        alu_src,
    output logic        reg_write,
    output logic        mem_read,
    output logic        mem_write,
    output logic        mem_to_reg,
    output logic        lui,
    output logic        auipc,
    output logic        jal,
    output logic        jalr,
    output logic [63:0] data_memory_read_data,
    output logic [63:0] write_back_data,

    // M unit
    output logic        is_word,
    output logic        mul_en,
    output logic [63:0] m_result,

    // F unit
    output logic        fp_en,
    output logic [1:0]  fp_op,
    output logic        fp_reg_write,
    output logic [31:0] fp_read_data1,
    output logic [31:0] fp_read_data2,
    output logic [31:0] fp_result
);

    // ==========================================
    // INTERNAL SIGNALS
    // ==========================================
    logic [63:0] next_pc;
    logic        zero;
    logic        branch;
    logic        branch_taken;
    logic [63:0] alu_input_b;
    logic [63:0] store_data;
    logic [31:0] fp_write_data;
    logic        fp_load;
    logic        fp_store;

    // ==========================================
    // PROGRAM COUNTER
    // ==========================================
    program_counter PC (
        .clk(clk),
        .reset(reset),
        .next_pc(next_pc),
        .pc(pc)
    );

    // ==========================================
    // INSTRUCTION MEMORY
    // ==========================================
    instruction_memory IMEM (
        .address(pc),
        .instruction(instruction)
    );

    // ==========================================
    // INSTRUCTION DECODER
    // ==========================================
    instruction_decoder DECODER (
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .funct3(funct3),
        .rs1(rs1),
        .rs2(rs2),
        .funct7(funct7)
    );

    // ==========================================
    // IMMEDIATE GENERATOR
    // ==========================================
    immediate_generator IMM_GEN (
        .instruction(instruction),
        .immediate(immediate)
    );

    // ==========================================
    // CONTROL UNIT
    // ==========================================
    control_unit CU (
        .opcode(opcode),
        .funct3(funct3),
        .funct7(funct7),
        .reg_write(reg_write),
        .alu_src(alu_src),
        .alu_control(alu_control),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .lui(lui),
        .auipc(auipc),
        .jal(jal),
        .jalr(jalr),
        .branch(branch),
        .is_word(is_word),
        .mul_en(mul_en),
        .fp_en(fp_en),
        .fp_op(fp_op),
        .fp_load(fp_load),
        .fp_store(fp_store),
        .fp_reg_write(fp_reg_write)
    );

    // ==========================================
    // INTEGER REGISTER FILE
    // ==========================================
    register_file REG_FILE (
        .clk(clk),
        .reset(reset),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(write_back_data),
        .reg_write(reg_write),
        .read_data1(read_data1),
        .read_data2(read_data2)
    );

    // ==========================================
    // FLOATING POINT REGISTER FILE
    // ==========================================
    fp_register_file FP_REG_FILE (
        .clk(clk),
        .reset(reset),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .write_data(fp_write_data),
        .fp_reg_write(fp_reg_write),
        .read_data1(fp_read_data1),
        .read_data2(fp_read_data2)
    );

    // ==========================================
    // ALU INPUT B
    // ==========================================
    always_comb begin
        if (alu_src)
            alu_input_b = immediate;
        else
            alu_input_b = read_data2;
    end

    // ==========================================
    // ALU
    // ==========================================
    alu ALU (
        .a(read_data1),
        .b(alu_input_b),
        .alu_control(alu_control),
        .is_word(is_word),
        .result(alu_result),
        .zero(zero)
    );

    // ==========================================
    // M UNIT (MUL, MULH, MULHSU, MULHU, MULW)
    // ==========================================
    m_unit M_UNIT (
        .a(read_data1),
        .b(read_data2),
        .funct3(funct3),
        .is_word(is_word),
        .result(m_result)
    );

    // ==========================================
    // F UNIT (FADD.S, FSUB.S, FMUL.S)
    // ==========================================
    f_unit F_UNIT (
        .a(fp_read_data1),
        .b(fp_read_data2),
        .fp_op(fp_op),
        .result(fp_result)
    );

    // ==========================================
    // DATA MEMORY
    // ==========================================
    // FSW stores the floating point register, SB/SH/SW/SD store the integer register
    always_comb begin
        if (fp_store)
            store_data = {32'b0, fp_read_data2};
        else
            store_data = read_data2;
    end

    data_memory DATA_MEM (
        .clk(clk),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .address(alu_result),
        .write_data(store_data),
        .funct3(funct3),
        .read_data(data_memory_read_data)
    );

    // ==========================================
    // FLOATING POINT WRITE BACK
    // ==========================================
    always_comb begin
        if (fp_load)
            fp_write_data = data_memory_read_data[31:0];   // FLW
        else
            fp_write_data = fp_result;                     // FADD/FSUB/FMUL
    end

    // ==========================================
    // BRANCH CONDITION
    // ==========================================
    always_comb begin
        branch_taken = 1'b0;
        case (funct3)
            3'b000: branch_taken = (read_data1 == read_data2);                  // BEQ
            3'b001: branch_taken = (read_data1 != read_data2);                  // BNE
            3'b100: branch_taken = ($signed(read_data1) <  $signed(read_data2)); // BLT
            3'b101: branch_taken = ($signed(read_data1) >= $signed(read_data2)); // BGE
            3'b110: branch_taken = (read_data1 <  read_data2);                  // BLTU
            3'b111: branch_taken = (read_data1 >= read_data2);                  // BGEU
            default: branch_taken = 1'b0;
        endcase
    end

    // ==========================================
    // NEXT PC
    // ==========================================
    always_comb begin
        if (jal)
            next_pc = pc + immediate;
        else if (jalr)
            next_pc = (read_data1 + immediate) & 64'hFFFFFFFFFFFFFFFE;
        else if (branch && branch_taken)
            next_pc = pc + immediate;
        else
            next_pc = pc + 64'd4;
    end

    // ==========================================
    // WRITE BACK (integer register)
    // ==========================================
    always_comb begin
        if (lui)
            write_back_data = immediate;
        else if (auipc)
            write_back_data = pc + immediate;
        else if (jal || jalr)
            write_back_data = pc + 64'd4;
        else if (mem_to_reg)
            write_back_data = data_memory_read_data;   // load instructions
        else if (mul_en)
            write_back_data = m_result;                // MUL, MULW
        else
            write_back_data = alu_result;
    end

endmodule


