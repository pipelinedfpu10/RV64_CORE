// Byte addressable data memory (2048 bytes), little endian
module data_memory (
    input  logic        clk,
    input  logic        mem_read,
    input  logic        mem_write,
    input  logic [63:0] address,
    input  logic [63:0] write_data,
    input  logic [2:0]  funct3,
    output logic [63:0] read_data
);

    logic [7:0]  memory [0:2047];
    logic [10:0] a;                 // byte address inside memory
    logic [63:0] dword;             // 8 bytes starting at address
    integer i;

    assign a = address[10:0];

    initial begin
        for (i = 0; i < 2048; i = i + 1)
            memory[i] = 8'h00;
    end

    //------------------------------------------------
    // WRITE
    //------------------------------------------------
    always @(posedge clk) begin   // plain always (not always_ff) because 'initial' also writes memory
        if (mem_write) begin
            case (funct3)
                // SB - Store Byte
                3'b000: begin
                    memory[a] <= write_data[7:0];
                end
                // SH - Store Halfword
                3'b001: begin
                    memory[a]          <= write_data[7:0];
                    memory[a + 11'd1]  <= write_data[15:8];
                end
                // SW / FSW - Store Word
                3'b010: begin
                    memory[a]          <= write_data[7:0];
                    memory[a + 11'd1]  <= write_data[15:8];
                    memory[a + 11'd2]  <= write_data[23:16];
                    memory[a + 11'd3]  <= write_data[31:24];
                end
                // SD - Store Doubleword
                3'b011: begin
                    memory[a]          <= write_data[7:0];
                    memory[a + 11'd1]  <= write_data[15:8];
                    memory[a + 11'd2]  <= write_data[23:16];
                    memory[a + 11'd3]  <= write_data[31:24];
                    memory[a + 11'd4]  <= write_data[39:32];
                    memory[a + 11'd5]  <= write_data[47:40];
                    memory[a + 11'd6]  <= write_data[55:48];
                    memory[a + 11'd7]  <= write_data[63:56];
                end
                default: begin
                    // Do nothing
                end
            endcase
        end
    end

    //------------------------------------------------
    // READ
    //------------------------------------------------
    always_comb begin
        dword = {memory[a + 11'd7], memory[a + 11'd6],
                 memory[a + 11'd5], memory[a + 11'd4],
                 memory[a + 11'd3], memory[a + 11'd2],
                 memory[a + 11'd1], memory[a]};

        read_data = 64'b0;

        if (mem_read) begin
            case (funct3)
                // LB  - Load Byte
                3'b000: read_data = {{56{dword[7]}},  dword[7:0]};
                // LH  - Load Halfword
                3'b001: read_data = {{48{dword[15]}}, dword[15:0]};
                // LW / FLW - Load Word
                3'b010: read_data = {{32{dword[31]}}, dword[31:0]};
                // LD  - Load Doubleword
                3'b011: read_data = dword;
                // LBU - Load Byte Unsigned
                3'b100: read_data = {56'b0, dword[7:0]};
                // LHU - Load Halfword Unsigned
                3'b101: read_data = {48'b0, dword[15:0]};
                // LWU - Load Word Unsigned
                3'b110: read_data = {32'b0, dword[31:0]};
                default: read_data = 64'b0;
            endcase
        end
    end

endmodule
