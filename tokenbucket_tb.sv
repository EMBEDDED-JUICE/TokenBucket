`timescale 1ns/1ns

module tb_one_shot;
    // ---- Params ----
    localparam PULSE_LEN = 6;

    // ---- DUT I/O ----
    reg  clk, rst_n, trig;
    wire y_non, y_retrig;

    one_shot #(.PULSE_LEN(PULSE_LEN), .RETRIGGERABLE(0)) dut_non (
        .clk(clk), .rst_n(rst_n), .trig(trig), .y(y_non)
    );

    one_shot #(.PULSE_LEN(PULSE_LEN), .RETRIGGERABLE(1)) dut_retrig (
        .clk(clk), .rst_n(rst_n), .trig(trig), .y(y_retrig)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // VCD
    initial begin
        $dumpfile("one_shot.vcd");
        $dumpvars(0, tb_one_shot);
    end

    // ----------------- Scoreboard state (module-scope) -----------------
    integer cnt_non, cnt_re;
    reg     exp_y_non_q, exp_y_re_q;  // expected y to compare at *this* posedge
    reg     trig_q;
    integer errors;
    // Temps also at module-scope (avoid block-scoped decls)
    reg     trig_rise;
    integer next_non, next_re;
    integer r, i, k; // used in stimulus/tasks

    // Single scoreboard tick per posedge
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_non     <= 0;
            cnt_re      <= 0;
            exp_y_non_q <= 1'b0;
            exp_y_re_q  <= 1'b0;
            trig_q      <= 1'b0;
            errors      <= 0;
        end else begin
            // Compare DUT outputs (DUT y is registered from next-state)
            if (y_non    !== exp_y_non_q) begin
                $display("MISMATCH(NON) @%0t: exp=%0d got=%0d (cnt_non=%0d)", $time, exp_y_non_q, y_non, cnt_non);
                errors <= errors + 1;
            end
            if (y_retrig !== exp_y_re_q) begin
                $display("MISMATCH(RETRIG) @%0t: exp=%0d got=%0d (cnt_re=%0d)", $time, exp_y_re_q, y_retrig, cnt_re);
                errors <= errors + 1;
            end

            // Compute next expected (mirror DUT logic)
            trig_rise = trig & ~trig_q;

            // NON-RETRIGGERABLE
            next_non = cnt_non;
            if (trig_rise) begin
                if (cnt_non == 0) next_non = PULSE_LEN;
                else               next_non = (cnt_non == 0) ? 0 : (cnt_non - 1); // ignore retrigger
            end else if (cnt_non > 0) next_non = cnt_non - 1;
            else                       next_non = 0;

            // RETRIGGERABLE
            next_re = cnt_re;
            if (trig_rise)            next_re = PULSE_LEN; // start/extend
            else if (cnt_re > 0)      next_re = cnt_re - 1;
            else                      next_re = 0;

            // Update refs + expected outputs for next cycle
            cnt_non     <= next_non;
            cnt_re      <= next_re;
            exp_y_non_q <= (next_non != 0);
            exp_y_re_q  <= (next_re  != 0);
            trig_q      <= trig;
        end
    end

    // ----------------- Stimulus (no scoreboard calls) -----------------
    task pulse;
        input integer cycles; // hold 'trig' high for N cycles
        begin
            @(negedge clk); trig <= 1'b1;
            for (k = 0; k < cycles; k = k + 1) @(posedge clk);
            @(negedge clk); trig <= 1'b0;
        end
    endtask

    task idle;
        input integer cycles; // keep 'trig' low for N cycles
        begin
            @(negedge clk); trig <= 1'b0;
            for (k = 0; k < cycles; k = k + 1) @(posedge clk);
        end
    endtask

    initial begin
        // Reset
        trig = 1'b0; rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // P1) Single short trigger
        pulse(1); repeat (PULSE_LEN+2) @(posedge clk);

        // P2) Dense triggers inside active window
        pulse(1); repeat (2) @(posedge clk);
        pulse(1); repeat (2) @(posedge clk);
        pulse(1); repeat (PULSE_LEN+4) @(posedge clk);

        // P3) Back-to-back triggers separated by >= PULSE_LEN
        idle(3);
        pulse(1); repeat (PULSE_LEN+1) @(posedge clk);
        pulse(1); repeat (PULSE_LEN+1) @(posedge clk);

        // P4) Random-ish bursts using $random
        for (i = 0; i < 50; i = i + 1) begin
            r = $random; if (r < 0) r = -r;
            if (r % 2) begin
                pulse((r % 2) + 1); // 1–2 cycles high
            end else begin
                idle((r % 4) + 1);  // 1–4 cycles low
            end
            @(posedge clk);
        end

        // Report
        $display("====================================================");
        $display("Errors: %0d", errors);
        if (errors == 0) $display("RESULT: PASS ");
        else             $display("RESULT: FAIL ");
        $display("VCD written to one_shot.vcd");
        $display("====================================================");
        $finish;
    end
endmodule
