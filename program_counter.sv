module program_counter (
    input  logic        clk,
    input  logic        reset,
    input  logic [63:0] next_pc,
    output logic [63:0] pc
);

    always_ff @(posedge clk) begin
        if (reset)
            pc <= 64'h0000000000000000;
        else
            pc <= next_pc;
    end

endmodule


