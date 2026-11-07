// Floating point register file: 32 registers, each 32 bits wide (single precision)
module fp_register_file (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [31:0] write_data,
    input  logic        fp_reg_write,
    output logic [31:0] read_data1,
    output logic [31:0] read_data2
);

    logic [31:0] fp_registers [0:31];
    integer i;

    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                fp_registers[i] <= 32'b0;
        end
        else if (fp_reg_write) begin
            fp_registers[rd] <= write_data;   // f0 is a normal register
        end
    end

    always_comb begin
        read_data1 = fp_registers[rs1];
        read_data2 = fp_registers[rs2];
    end

endmodule


