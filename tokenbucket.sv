`timescale 1ns/1ps

module one_shot #(
    parameter int PULSE_LEN     = 6,  // >= 1
    parameter bit RETRIGGERABLE = 0
)(
    input  logic clk,
    input  logic rst_n,   // active-low synchronous reset
    input  logic trig,    // synchronous trigger
    output logic y        // 1 while pulse is active
);

    // Ceil log2 helper: enough bits for [0..PULSE_LEN]
    function automatic int clog2_plus1(input int n);
        int w; begin
            w = 0; while ((1 << w) < n) w++;
            return (w == 0) ? 1 : w;
        end
    endfunction
    localparam int CW = clog2_plus1(PULSE_LEN + 1);

    // State
    logic          trig_q;
    logic [CW-1:0] cnt_q, cnt_n;

    // Sync edge detect
    always_ff @(posedge clk) begin
        if (!rst_n) trig_q <= 1'b0;
        else        trig_q <= trig;
    end
    wire trig_rise = trig & ~trig_q;
    wire active    = (cnt_q != '0);

    // Next-state counter
    always_comb begin
        cnt_n = cnt_q;
        if (trig_rise) begin
            if (!active || RETRIGGERABLE) cnt_n = PULSE_LEN[CW-1:0];       // start/extend
            else                          cnt_n = (cnt_q == '0) ? '0 : (cnt_q - 1); // ignore retrigger
        end
        else if (active) begin
            cnt_n = cnt_q - 1;
        end
        else begin
            cnt_n = '0;
        end
    end

    // State update + registered output reflecting next-state
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cnt_q <= '0;
            y     <= 1'b0;
        end else begin
            cnt_q <= cnt_n;
            y     <= (cnt_n != '0);
        end
    end

    // Parameter guard (sim aid)
    initial if (PULSE_LEN < 1) $error("PULSE_LEN must be >= 1");

endmodule
