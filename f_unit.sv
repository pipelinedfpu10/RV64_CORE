// F Unit: single precision FADD.S, FSUB.S, FMUL.S
// Simple version:
//   - rounding: round to nearest even (rm field ignored)
//   - zero/sub-normal inputs are treated as zero
//   - sub-normal results are flushed to zero
//   - NaN result is always 32'h7FC00000
//   - exception flags are not used
// fp_op: 2'b00 = FADD, 2'b01 = FSUB, 2'b10 = FMUL
module f_unit (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic [1:0]  fp_op,
    output logic [31:0] result
);

    logic [31:0] add_sub_result;
    logic [31:0] mul_result;

    fp_add_sub ADD_SUB (
        .a(a),
        .b(b),
        .sub(fp_op[0]),
        .result(add_sub_result)
    );

    fp_mul MUL (
        .a(a),
        .b(b),
        .result(mul_result)
    );

    always_comb begin
        case (fp_op)
            2'b00:   result = add_sub_result;   // FADD.S
            2'b01:   result = add_sub_result;   // FSUB.S
            2'b10:   result = mul_result;       // FMUL.S
            default: result = 32'b0;
        endcase
    end

endmodule


// ======================================================
// FLOATING POINT ADD / SUBTRACT
// ======================================================
module fp_add_sub (
    input  logic [31:0] a,
    input  logic [31:0] b,
    input  logic        sub,       // 1 = subtract (flip sign of b)
    output logic [31:0] result
);

    logic [31:0] b_eff;
    logic        sign_a, sign_b;
    logic [7:0]  exp_a, exp_b;
    logic [22:0] man_a, man_b;
    logic        a_nan, b_nan, a_inf, b_inf, a_zero, b_zero;

    logic        swap;
    logic        big_sign, small_sign, result_sign;
    logic [7:0]  big_exp, small_exp, exp_diff;
    logic [26:0] big_man, small_man, small_shifted;   // {hidden, 23 fraction, guard, round, sticky}
    logic [27:0] sum;
    logic [26:0] norm;
    logic [24:0] rounded;
    logic [22:0] mant;
    logic        round_up;
    integer      exp_res, lz, k;
    logic        found;

    always_comb begin
        // -------- default values (avoid latches) --------
        b_eff         = {b[31] ^ sub, b[30:0]};
        sign_a = a[31];     exp_a = a[30:23];     man_a = a[22:0];
        sign_b = b_eff[31]; exp_b = b_eff[30:23]; man_b = b_eff[22:0];

        a_nan  = (exp_a == 8'hFF) && (man_a != 23'd0);
        b_nan  = (exp_b == 8'hFF) && (man_b != 23'd0);
        a_inf  = (exp_a == 8'hFF) && (man_a == 23'd0);
        b_inf  = (exp_b == 8'hFF) && (man_b == 23'd0);
        a_zero = (exp_a == 8'd0);
        b_zero = (exp_b == 8'd0);

        swap = 1'b0;  big_sign = 1'b0;  small_sign = 1'b0;  result_sign = 1'b0;
        big_exp = 8'd0;  small_exp = 8'd0;  exp_diff = 8'd0;
        big_man = 27'd0; small_man = 27'd0; small_shifted = 27'd0;
        sum = 28'd0;  norm = 27'd0;  rounded = 25'd0;  mant = 23'd0;
        round_up = 1'b0;  exp_res = 0;  lz = 0;  k = 0;  found = 1'b0;
        result = 32'd0;

        // -------- special cases --------
        if (a_nan || b_nan)
            result = 32'h7FC00000;
        else if (a_inf && b_inf)
            result = (sign_a == sign_b) ? a : 32'h7FC00000;
        else if (a_inf)
            result = a;
        else if (b_inf)
            result = b_eff;
        else if (a_zero && b_zero)
            result = {sign_a & sign_b, 31'd0};
        else if (a_zero)
            result = b_eff;
        else if (b_zero)
            result = a;

        // -------- normal numbers --------
        else begin
            // 1) Find the bigger number (by magnitude)
            swap = ({exp_b, man_b} > {exp_a, man_a});

            if (swap) begin
                big_sign   = sign_b;  big_exp   = exp_b;  big_man   = {1'b1, man_b, 3'b000};
                small_sign = sign_a;  small_exp = exp_a;  small_man = {1'b1, man_a, 3'b000};
            end
            else begin
                big_sign   = sign_a;  big_exp   = exp_a;  big_man   = {1'b1, man_a, 3'b000};
                small_sign = sign_b;  small_exp = exp_b;  small_man = {1'b1, man_b, 3'b000};
            end

            // 2) Align the smaller number (keep lost bits in the sticky bit)
            exp_diff = big_exp - small_exp;

            if (exp_diff > 8'd26) begin
                small_shifted = 27'd1;
            end
            else begin
                small_shifted = small_man >> exp_diff;
                if ((small_man & ((27'd1 << exp_diff) - 27'd1)) != 27'd0)
                    small_shifted[0] = 1'b1;
            end

            // 3) Add or subtract the mantissas
            if (big_sign == small_sign)
                sum = {1'b0, big_man} + {1'b0, small_shifted};
            else
                sum = {1'b0, big_man} - {1'b0, small_shifted};

            result_sign = big_sign;

            // 4) Normalize
            if (sum == 28'd0) begin
                result = 32'd0;
            end
            else begin
                if (sum[27]) begin
                    // carry out: shift right by 1
                    norm    = {sum[27:2], sum[1] | sum[0]};
                    exp_res = big_exp + 1;
                end
                else begin
                    // find the first 1 and shift left
                    lz    = 0;
                    found = 1'b0;
                    for (k = 26; k >= 0; k = k - 1) begin
                        if (!found) begin
                            if (sum[k]) found = 1'b1;
                            else        lz = lz + 1;
                        end
                    end
                    norm    = sum[26:0] << lz;
                    exp_res = big_exp - lz;
                end

                // 5) Round to nearest even
                round_up = norm[2] & (norm[1] | norm[0] | norm[3]);
                rounded  = {1'b0, norm[26:3]} + {24'd0, round_up};

                if (rounded[24]) begin
                    exp_res = exp_res + 1;
                    mant    = rounded[23:1];
                end
                else begin
                    mant    = rounded[22:0];
                end

                // 6) Pack the result
                if (exp_res >= 255)
                    result = {result_sign, 8'hFF, 23'd0};        // overflow -> infinity
                else if (exp_res <= 0)
                    result = {result_sign, 31'd0};               // underflow -> zero
                else
                    result = {result_sign, exp_res[7:0], mant};
            end
        end
    end

endmodule


// ======================================================
// FLOATING POINT MULTIPLY (mantissa multiply = shift and add)
// ======================================================
module fp_mul (
    input  logic [31:0] a,
    input  logic [31:0] b,
    output logic [31:0] result
);

    logic        sign;
    logic [7:0]  exp_a, exp_b;
    logic [22:0] man_a, man_b;
    logic        a_nan, b_nan, a_inf, b_inf, a_zero, b_zero;

    logic [23:0] ma, mb;
    logic [47:0] prod;
    logic [23:0] mant24;
    logic [24:0] rounded;
    logic [22:0] mant;
    logic        guard, sticky, lsb, round_up;
    integer      exp_res, i;

    always_comb begin
        // -------- default values (avoid latches) --------
        sign  = a[31] ^ b[31];
        exp_a = a[30:23];  man_a = a[22:0];
        exp_b = b[30:23];  man_b = b[22:0];

        a_nan  = (exp_a == 8'hFF) && (man_a != 23'd0);
        b_nan  = (exp_b == 8'hFF) && (man_b != 23'd0);
        a_inf  = (exp_a == 8'hFF) && (man_a == 23'd0);
        b_inf  = (exp_b == 8'hFF) && (man_b == 23'd0);
        a_zero = (exp_a == 8'd0);
        b_zero = (exp_b == 8'd0);

        ma = 24'd0;  mb = 24'd0;  prod = 48'd0;  mant24 = 24'd0;
        rounded = 25'd0;  mant = 23'd0;
        guard = 1'b0;  sticky = 1'b0;  lsb = 1'b0;  round_up = 1'b0;
        exp_res = 0;  i = 0;
        result = 32'd0;

        // -------- special cases --------
        if (a_nan || b_nan)
            result = 32'h7FC00000;
        else if ((a_inf && b_zero) || (b_inf && a_zero))
            result = 32'h7FC00000;
        else if (a_inf || b_inf)
            result = {sign, 8'hFF, 23'd0};
        else if (a_zero || b_zero)
            result = {sign, 31'd0};

        // -------- normal numbers --------
        else begin
            ma = {1'b1, man_a};
            mb = {1'b1, man_b};

            // 24 x 24 bit multiply using shift and add
            prod = 48'd0;
            for (i = 0; i < 24; i = i + 1) begin
                if (mb[i])
                    prod = prod + ({24'd0, ma} << i);
            end

            exp_res = exp_a + exp_b - 127;

            // product is 1x.xxxx or 01.xxxx
            if (prod[47]) begin
                mant24  = prod[47:24];
                guard   = prod[23];
                sticky  = |prod[22:0];
                exp_res = exp_res + 1;
            end
            else begin
                mant24  = prod[46:23];
                guard   = prod[22];
                sticky  = |prod[21:0];
            end

            // Round to nearest even
            lsb      = mant24[0];
            round_up = guard & (sticky | lsb);
            rounded  = {1'b0, mant24} + {24'd0, round_up};

            if (rounded[24]) begin
                exp_res = exp_res + 1;
                mant    = rounded[23:1];
            end
            else begin
                mant    = rounded[22:0];
            end

            // Pack the result
            if (exp_res >= 255)
                result = {sign, 8'hFF, 23'd0};
            else if (exp_res <= 0)
                result = {sign, 31'd0};
            else
                result = {sign, exp_res[7:0], mant};
        end
    end

endmodule


