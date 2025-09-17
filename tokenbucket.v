`timescale 1ns/1ns

module one_shot #(
    parameter PULSE_LEN     = 8,   // >= 1
    parameter RETRIGGERABLE = 0
)(
    input  clk,
    input  rst_n,   // active-low synchronous reset
    input  trig,    // synchronous trigger
    output reg y    // 1 while pulse is active
);

    // Verilog-2001-friendly ceil(log2(PULSE_LEN+1))
    function integer CLOG2;
        input integer value;
        integer i;
        begin
            value = value - 1;
            for (i = 0; value > 0; i = i + 1)
                value = value >> 1;
            if (i == 0) CLOG2 = 1; else CLOG2 = i;
        end
    endfunction

    localparam CW = CLOG2(PULSE_LEN + 1);

    reg              trig_q;
    reg [CW-1:0]     cnt_q, cnt_n;
    wire             trig_rise = trig & ~trig_q;
    wire             active    = (cnt_q != {CW{1'b0}});

    // sample trigger
    always @(posedge clk) begin
        if (!rst_n) trig_q <= 1'b0;
        else        trig_q <= trig;
    end

    // next-state counter
    always @* begin
        cnt_n = cnt_q;
        if (trig_rise) begin
            if (!active || (RETRIGGERABLE != 0))
                cnt_n = PULSE_LEN; // start/extend
            else
                cnt_n = (cnt_q == {CW{1'b0}}) ? cnt_q : (cnt_q - {{(CW-1){1'b0}},1'b1}); // ignore retrigger
        end else if (active) begin
            cnt_n = cnt_q - {{(CW-1){1'b0}},1'b1};
        end else begin
            cnt_n = {CW{1'b0}};
        end
    end

    // state + registered output aligned to next-state
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_q <= {CW{1'b0}};
            y     <= 1'b0;
        end else begin
            cnt_q <= cnt_n;
            y     <= (cnt_n != {CW{1'b0}});
        end
    end

    initial begin
        if (PULSE_LEN < 1) $display("ERROR: PULSE_LEN must be >= 1");
    end
endmodule

