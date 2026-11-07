// ==========================================
// RV64IMF CORE TESTBENCH  (checks PASS / FAIL)
// Needs test.hex in the simulation folder
// ==========================================
module tb_rv64_core;

    logic clk;
    logic reset;

    logic [63:0]  pc;
    logic [31:0]  instruction;
    logic [6:0]   opcode;
    logic [4:0]   rd;
    logic [2:0]   funct3;
    logic [4:0]   rs1;
    logic [4:0]   rs2;
    logic [6:0]   funct7;
    logic [63:0]  read_data1;
    logic [63:0]  read_data2;
    logic [63:0]  immediate;
    logic [63:0]  alu_result;
    logic [3:0]   alu_control;
    logic         alu_src;
    logic         reg_write;
    logic         mem_read;
    logic         mem_write;
    logic         mem_to_reg;
    logic         lui;
    logic         auipc;
    logic         jal;
    logic         jalr;
    logic [63:0]  data_memory_read_data;
    logic [63:0]  write_back_data;
    logic         is_word;
    logic         mul_en;
    logic [63:0]  m_result;
    logic         fp_en;
    logic [1:0]   fp_op;
    logic         fp_reg_write;
    logic [31:0]  fp_read_data1;
    logic [31:0]  fp_read_data2;
    logic [31:0]  fp_result;

    integer pass_count;
    integer fail_count;

    // ==========================================
    // DUT
    // ==========================================
    rv64_core DUT (
        .clk(clk),
        .reset(reset),
        .pc(pc),
        .instruction(instruction),
        .opcode(opcode),
        .rd(rd),
        .funct3(funct3),
        .rs1(rs1),
        .rs2(rs2),
        .funct7(funct7),
        .read_data1(read_data1),
        .read_data2(read_data2),
        .immediate(immediate),
        .alu_result(alu_result),
        .alu_control(alu_control),
        .alu_src(alu_src),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_to_reg(mem_to_reg),
        .lui(lui),
        .auipc(auipc),
        .jal(jal),
        .jalr(jalr),
        .data_memory_read_data(data_memory_read_data),
        .write_back_data(write_back_data),
        .is_word(is_word),
        .mul_en(mul_en),
        .m_result(m_result),
        .fp_en(fp_en),
        .fp_op(fp_op),
        .fp_reg_write(fp_reg_write),
        .fp_read_data1(fp_read_data1),
        .fp_read_data2(fp_read_data2),
        .fp_result(fp_result)
    );

    // ==========================================
    // CLOCK
    // ==========================================
    always #5 clk = ~clk;

    // ==========================================
    // INTEGER REGISTER CHECK
    // ==========================================
    task check_register(
        input integer       reg_number,
        input logic [63:0]  expected_value
    );
        begin
            if (DUT.REG_FILE.registers[reg_number] === expected_value) begin
                pass_count = pass_count + 1;
                $display("PASS: x%0d = %016h", reg_number, expected_value);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: x%0d = %016h, Expected = %016h",
                         reg_number,
                         DUT.REG_FILE.registers[reg_number],
                         expected_value);
            end
        end
    endtask

    // ==========================================
    // FLOATING POINT REGISTER CHECK
    // ==========================================
    task check_fp_register(
        input integer       reg_number,
        input logic [31:0]  expected_value
    );
        begin
            if (DUT.FP_REG_FILE.fp_registers[reg_number] === expected_value) begin
                pass_count = pass_count + 1;
                $display("PASS: f%0d = %08h", reg_number, expected_value);
            end
            else begin
                fail_count = fail_count + 1;
                $display("FAIL: f%0d = %08h, Expected = %08h",
                         reg_number,
                         DUT.FP_REG_FILE.fp_registers[reg_number],
                         expected_value);
            end
        end
    endtask

    // ==========================================
    // WAIT UNTIL THE PC REACHES AN ADDRESS
    // (all instructions before that address are finished)
    // ==========================================
    task run_until(
        input logic [63:0] target_pc
    );
        integer timeout;
        begin
            timeout = 0;
            while ((pc !== target_pc) && (timeout < 1000)) begin
                @(posedge clk); #1;
                timeout = timeout + 1;
            end
            if (timeout >= 1000) begin
                fail_count = fail_count + 1;
                $display("FAIL: timeout, PC never reached %h", target_pc);
            end
        end
    endtask

    // ==========================================
    // TEST
    // ==========================================
    initial begin
        clk        = 1'b0;
        reset      = 1'b1;
        pass_count = 0;
        fail_count = 0;

        // ------------------------------------------
        // RESET
        // ------------------------------------------
        #12;
        reset = 1'b0;

        // ------------------------------------------
        // I-TYPE and R-TYPE (64-bit)
        // ------------------------------------------
        $display("");
        $display("---- I-TYPE and R-TYPE ----");
        run_until(64'h0000000000000050);
        check_register(1, 64'h0000000000000005);
        check_register(2, 64'hFFFFFFFFFFFFFFFD);
        check_register(3, 64'h0000000000000001);
        check_register(4, 64'h0000000000000000);
        check_register(5, 64'h000000000000000A);
        check_register(6, 64'h0000000000000035);
        check_register(7, 64'h0000000000000005);
        check_register(8, 64'h0000050000000000);
        check_register(9, 64'h0000000000000050);
        check_register(10, 64'hFFFFFFFFFFFFFFFE);
        check_register(11, 64'h0000000000000002);
        check_register(12, 64'h0000000000000008);
        check_register(13, 64'h00000000000000A0);
        check_register(14, 64'h0000000000000001);
        check_register(15, 64'h0000000000000001);
        check_register(16, 64'hFFFFFFFFFFFFFFF8);
        check_register(17, 64'h07FFFFFFFFFFFFFF);
        check_register(18, 64'hFFFFFFFFFFFFFFFF);
        check_register(19, 64'h0000050000000005);
        check_register(20, 64'h0000000000000005);

        // ------------------------------------------
        // W INSTRUCTIONS (32-bit, sign extended)
        // ------------------------------------------
        $display("");
        $display("---- W INSTRUCTIONS ----");
        run_until(64'h000000000000007C);
        check_register(21, 64'hFFFFFFFF80000000);
        check_register(22, 64'h000000007FFFFFFF);
        check_register(23, 64'hFFFFFFFF7FFFFFFF);
        check_register(24, 64'hFFFFFFFF80000000);
        check_register(25, 64'h0000000008000000);
        check_register(26, 64'hFFFFFFFFF8000000);
        check_register(27, 64'hFFFFFFFF80000004);
        check_register(28, 64'h000000007FFFFFFB);
        check_register(29, 64'h00000000000000A0);
        check_register(30, 64'h0000000004000000);
        check_register(31, 64'hFFFFFFFFFC000000);

        // ------------------------------------------
        // LOAD / STORE (LB LH LW LD LBU LHU LWU SB SH SW SD)
        // ------------------------------------------
        $display("");
        $display("---- LOAD / STORE ----");
        run_until(64'h00000000000000EC);
        check_register(1, 64'h0000000000000100);
        check_register(2, 64'h123456789ABCDEF0);
        check_register(3, 64'h000000009ABCDEF0);
        check_register(4, 64'h123456789ABCDEF0);
        check_register(5, 64'hFFFFFFFF9ABCDEF0);
        check_register(6, 64'h000000009ABCDEF0);
        check_register(7, 64'h0000000012345678);
        check_register(8, 64'hFFFFFFFFFFFFDEF0);
        check_register(9, 64'h000000000000DEF0);
        check_register(10, 64'hFFFFFFFFFFFFFFF0);
        check_register(11, 64'h00000000000000F0);
        check_register(12, 64'h0000000000000012);
        check_register(14, 64'h0000000000000055);
        check_register(16, 64'h000000000000FFFE);
        check_register(17, 64'h9ABCDEF09ABCDEF0);

        // ------------------------------------------
        // BRANCH / JAL / JALR / AUIPC (x20 = 0 means no wrong path ran, x21 = 6 not-taken branches)
        // ------------------------------------------
        $display("");
        $display("---- BRANCH / JAL / JALR / AUIPC ----");
        run_until(64'h000000000000019C);
        check_register(20, 64'h0000000000000000);
        check_register(21, 64'h0000000000000006);
        check_register(22, 64'h000000000000000F);
        check_register(23, 64'h0000000000000000);
        check_register(24, 64'h000000000000018C);
        check_register(25, 64'h0000000000000190);
        check_register(27, 64'h0000000000000198);

        // ------------------------------------------
        // M EXTENSION (MUL, MULH, MULHSU, MULHU, MULW - shift and add)
        // ------------------------------------------
        $display("");
        $display("---- M EXTENSION ----");
        run_until(64'h0000000000000224);
        check_register(3, 64'h000000000000002A);
        check_register(5, 64'hFFFFFFFFFFFFFFD6);
        check_register(6, 64'h0000000000000031);
        check_register(8, 64'h0000000000000000);
        check_register(9, 64'h0000000700000000);
        check_register(10, 64'h0000000000000000);
        check_register(12, 64'hFFFFFFFE00000001);
        check_register(14, 64'h000000007FFFFFFF);
        check_register(15, 64'hFFFFFFFFFFFFFFFA);
        check_register(16, 64'h000000000000002A);
        check_register(17, 64'h8000000000000000);
        check_register(18, 64'hFFFFFFFFFFFFFFFF);
        check_register(19, 64'hFFFFFFFFFFFFFFFF);
        check_register(20, 64'h0000000000000000);
        check_register(21, 64'h0000000000000001);
        check_register(22, 64'h0000000000000001);
        check_register(23, 64'hFFFFFFFFFFFFFFFE);
        check_register(24, 64'hFFFFFFFFFFFFFFFF);
        check_register(25, 64'h0000000000000006);
        check_register(26, 64'h4000000000000000);
        check_register(27, 64'h4000000000000000);
        check_register(28, 64'hC000000000000000);
        check_register(29, 64'h0000000000000000);
        check_register(30, 64'hFFFFFFFFFFFFFFFF);
        check_register(31, 64'h0000000000000000);

        // ------------------------------------------
        // F EXTENSION (FLW, FSW, FADD.S, FSUB.S, FMUL.S)
        // ------------------------------------------
        $display("");
        $display("---- F EXTENSION ----");
        run_until(64'h00000000000002CC);
        check_register(20, 64'h0000000040580000);
        check_fp_register(0, 32'h3FC00000);
        check_fp_register(1, 32'h40100000);
        check_fp_register(2, 32'h3DCCCCCD);
        check_fp_register(3, 32'h3E4CCCCD);
        check_fp_register(4, 32'hC0800000);
        check_fp_register(5, 32'h3F800000);
        check_fp_register(6, 32'h60AD78EC);
        check_fp_register(7, 32'h40400000);
        check_fp_register(8, 32'h40700000);
        check_fp_register(9, 32'hBF400000);
        check_fp_register(10, 32'h40580000);
        check_fp_register(11, 32'h3E99999A);
        check_fp_register(12, 32'h3CA3D70B);
        check_fp_register(13, 32'hC0C00000);
        check_fp_register(14, 32'h00000000);
        check_fp_register(15, 32'h60AD78EC);
        check_fp_register(16, 32'h3F400000);
        check_fp_register(17, 32'h7F800000);
        check_fp_register(18, 32'hC0200000);

        // ------------------------------------------
        // RESULT
        // ------------------------------------------
        $display("");
        $display("==============================================");
        $display(" RV64IMF TEST COMPLETED");
        $display(" PASS = %0d   FAIL = %0d", pass_count, fail_count);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" SOME TESTS FAILED");
        $display("==============================================");
        $display("");

        #10;
        $stop;
    end

endmodule


