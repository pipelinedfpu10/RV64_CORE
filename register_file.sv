// Integer register file: 32 registers, each 64 bits wide
module register_file (
    input  logic        clk,
    input  logic        reset,
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    input  logic [4:0]  rd,
    input  logic [63:0] write_data,
    input  logic        reg_write,
    output logic [63:0] read_data1,
    output logic [63:0] read_data2
);

    logic [63:0] registers [0:31];
    integer i;

    //------------------------------------------------
    // Synchronous Register Write (x0 is never written)
    //------------------------------------------------
    always_ff @(posedge clk) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                registers[i] <= 64'b0;
        end
        else if (reg_write && (rd != 5'd0)) begin
            registers[rd] <= write_data;
        end
    end

    //------------------------------------------------
    // Asynchronous Register Read (x0 always reads 0)
    //------------------------------------------------
    always_comb begin
        if (rs1 == 5'd0) read_data1 = 64'b0;
        else             read_data1 = registers[rs1];

        if (rs2 == 5'd0) read_data2 = 64'b0;
        else             read_data2 = registers[rs2];
    end

endmodule


