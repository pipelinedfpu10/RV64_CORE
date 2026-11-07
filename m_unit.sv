// M Unit: MUL, MULH, MULHSU, MULHU, MULW  (division is not included)
// The "*" operator is NOT used. The shift-and-add algorithm is used:
//   for every bit i of the multiplier that is 1,
//   add (multiplicand << i) to the 128-bit product.
//
// funct3: 000 = MUL     (low 64 bits)
//         001 = MULH    (high 64 bits, signed   x signed)
//         010 = MULHSU  (high 64 bits, signed   x unsigned)
//         011 = MULHU   (high 64 bits, unsigned x unsigned)
// is_word = 1 -> MULW (low 32 bits of the product, sign extended)
module m_unit (
    input  logic [63:0] a,          // rs1
    input  logic [63:0] b,          // rs2
    input  logic [2:0]  funct3,
    input  logic        is_word,    // 1 = MULW
    output logic [63:0] result
);

    logic        a_neg, b_neg;      // operand is treated as signed AND is negative
    logic [63:0] a_abs, b_abs;      // magnitudes (unsigned)
    logic [127:0] product;
    integer i;

    always_comb begin
        // ---- which operands are signed ----
        a_neg = 1'b0;
        b_neg = 1'b0;
        if (funct3 == 3'b001) begin          // MULH   : rs1 signed, rs2 signed
            a_neg = a[63];
            b_neg = b[63];
        end
        else if (funct3 == 3'b010) begin     // MULHSU : rs1 signed, rs2 unsigned
            a_neg = a[63];
        end

        // ---- magnitudes ----
        a_abs = a_neg ? (~a + 64'd1) : a;
        b_abs = b_neg ? (~b + 64'd1) : b;

        // MULW uses only the lower 32 bits of both inputs
        if (is_word) begin
            a_abs = {32'b0, a[31:0]};
            b_abs = {32'b0, b[31:0]};
        end

        // ---- shift and add (unsigned 64 x 64 -> 128 bits) ----
        product = 128'd0;
        for (i = 0; i < 64; i = i + 1) begin
            if (b_abs[i])
                product = product + ({64'd0, a_abs} << i);
        end

        // ---- fix the sign (two's complement) ----
        if (a_neg ^ b_neg)
            product = ~product + 128'd1;

        // ---- select the result ----
        if (is_word)
            result = {{32{product[31]}}, product[31:0]};   // MULW
        else if (funct3 == 3'b000)
            result = product[63:0];                        // MUL
        else
            result = product[127:64];                      // MULH, MULHSU, MULHU
    end

endmodule


