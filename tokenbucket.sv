`timescale 1ns/1ps

// One-shot pulse generator
// - If RETRIGGERABLE==0: ignore triggers while active
// - If RETRIGGERABLE==1: retrigger/extend to PULSE_LEN on each rising edge
module one_shot #(
    parameter PULSE_LEN     = 6,  // >=1
    parameter RETRIGGERABLE = 0   // 0=non-retriggerable, 1=retriggerable
)(
    input  wire clk,
    input  wire rst_n,   // active-low synchronous reset
    input  wire trig,    // synchronous trigger
    output reg  y        // 1 while pulse is active
);

    // State
    reg       trig_q;
    integer   cnt_q;   // counts remaining cycles in the active pulse
    integer   cnt_n;

    // Rising-edge detect for trig
    always @(posedge clk) begin
        if (!rst_n) trig_q <= 1'b0;
        else        trig_q <= trig;
    end
    wire trig_rise = trig & ~trig_q;

    // Next-state logic for the counter
    always @* begin
        integer next;
        next = cnt_q;

        if (trig_rise) begin
            if ((cnt_q == 0) || (RETRIGGERABLE != 0))
                next = PULSE_LEN;            // start or extend pulse
            else
                next = (cnt_q > 0) ? (cnt_q - 1) : 0; // ignore retrigger; keep counting down
        end
        else if (cnt_q > 0) begin
            next = cnt_q - 1;                // count down while active
        end
        else begin
            next = 0;                         // stay idle
        end

        cnt_n = next;
    end

    // Sequential state update and registered output
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_q <= 0;
            y     <= 1'b0;
        end else begin
            cnt_q <= cnt_n;
            y     <= (cnt_n != 0);
        end
    end

    // Simple parameter guard (simulation aid)
    initial begin
        if (PULSE_LEN < 1) begin
            $display("ERROR: PULSE_LEN must be >= 1");
            $finish;
        end
    end
endmodule
