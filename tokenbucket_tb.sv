`timescale 1ns/1ps

module tb_one_shot;

    // ---- Parameters to visualize behavior ----
    localparam int PULSE_LEN = 6;

    // ---- DUT I/O ----
    logic clk, rst_n, trig;
    logic y_non, y_retrig;

    // Two DUTs: non-retriggerable and retriggerable
    one_shot #(.PULSE_LEN(PULSE_LEN), .RETRIGGERABLE(1'b0)) dut_non (
        .clk(clk), .rst_n(rst_n), .trig(trig), .y(y_non)
    );
    one_shot #(.PULSE_LEN(PULSE_LEN), .RETRIGGERABLE(1'b1)) dut_re (
        .clk(clk), .rst_n(rst_n), .trig(trig), .y(y_retrig)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Wave dump
    initial begin
        $dumpfile("one_shot.sv.vcd");
        $dumpvars(0, tb_one_shot);
    end

    // ----------------- Scoreboard (aligned to registered outputs) -----------------
    // We compare DUT y (this cycle) to last cycle's expected y, then compute next expectations.
    int  cnt_non, cnt_re;
    bit  exp_y_non_q, exp_y_re_q;
    bit  trig_q;
    int  errors;

    // Single checker tick each posedge
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cnt_non      <= 0;
            cnt_re       <= 0;
            exp_y_non_q  <= 1'b0;
            exp_y_re_q   <= 1'b0;
            trig_q       <= 1'b0;
            errors       <= 0;
        end else begin
            // Compare DUT outputs against previous-cycle expectations
            if (y_non    !== exp_y_non_q) begin
                $display("MISMATCH(NON) @%0t: exp=%0d got=%0d (cnt_non=%0d)", $time, exp_y_non_q, y_non, cnt_non);
                errors <= errors + 1;
            end
            if (y_retrig !== exp_y_re_q) begin
                $display("MISMATCH(RETRIG) @%0t: exp=%0d got=%0d (cnt_re=%0d)", $time, exp_y_re_q, y_retrig, cnt_re);
                errors <= errors + 1;
            end

            // Compute next expectations (mirror DUT semantics)
            bit trig_rise = trig & ~trig_q;

            int next_non = cnt_non;
            if (trig_rise) begin
                if (cnt_non == 0) next_non = PULSE_LEN;
                else              next_non = (cnt_non == 0) ? 0 : (cnt_non - 1); // ignore retrigger
            end else if (cnt_non > 0) next_non = cnt_non - 1;
            else                       next_non = 0;

            int next_re = cnt_re;
            if (trig_rise)            next_re = PULSE_LEN; // start/extend
            else if (cnt_re > 0)      next_re = cnt_re - 1;
            else                      next_re = 0;

            // Update reference state and the "next" expected y
            cnt_non      <= next_non;
            cnt_re       <= next_re;
            exp_y_non_q  <= (next_non != 0);
            exp_y_re_q   <= (next_re  != 0);
            trig_q       <= trig;
        end
    end

    // ----------------- Stimulus (does not call the scoreboard) -----------------
    task automatic pulse(input int cycles);
        @(negedge clk); trig <= 1'b1;
        repeat (cycles) @(posedge clk);
        @(negedge clk); trig <= 1'b0;
    endtask

    task automatic idle(input int cycles);
        @(negedge clk); trig <= 1'b0;
        repeat (cycles) @(posedge clk);
    endtask

    initial begin
        // Reset
        trig = 1'b0; rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // P1) Single 1-cycle trigger
        pulse(1); repeat (PULSE_LEN+2) @(posedge clk);

        // P2) Dense triggers within active window:
        //     NON: still exactly PULSE_LEN; RETRIG: extends
        pulse(1); repeat (2) @(posedge clk);
        pulse(1); repeat (2) @(posedge clk);
        pulse(1); repeat (PULSE_LEN+3) @(posedge clk);

        // P3) Well-spaced triggers (>= PULSE_LEN apart)
        idle(3);
        pulse(1); repeat (PULSE_LEN+1) @(posedge clk);
        pulse(1); repeat (PULSE_LEN+1) @(posedge clk);

        // P4) Random bursts
        for (int k = 0; k < 40; k++) begin
            if ($urandom_range(0,1)) pulse($urandom_range(1,2)); // 1–2 high
            else                     idle($urandom_range(1,4));  // 1–4 low
            @(posedge clk);
        end

        // Report
        $display("====================================================");
        $display("Errors: %0d", errors);
        if (errors == 0) $display("RESULT: PASS ✅");
        else             $display("RESULT: FAIL ❌");
        $display("VCD written to one_shot.sv.vcd");
        $display("====================================================");
        $finish;
    end

endmodule
