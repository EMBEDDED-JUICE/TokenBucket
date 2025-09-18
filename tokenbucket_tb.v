`timescale 1ns/1ps

module tb_one_shot;

    // ---- Parameters to visualize behavior ----
    localparam PULSE_LEN = 6;

    // ---- DUT I/O ----
    reg  clk, rst_n, trig;
    wire y_non, y_retrig;

    // Two DUTs: non-retriggerable and retriggerable
    one_shot #(.PULSE_LEN(PULSE_LEN), .RETRIGGERABLE(0)) dut_non (
        .clk(clk), .rst_n(rst_n), .trig(trig), .y(y_non)
    );
    one_shot #(.PULSE_LEN(PULSE_LEN), .RETRIGGERABLE(1)) dut_re (
        .clk(clk), .rst_n(rst_n), .trig(trig), .y(y_retrig)
    );

    // 100 MHz clock
    initial begin
        clk = 1'b0;
        forever #5 clk = ~clk;
    end

    // Wave dump
    initial begin
        $dumpfile("one_shot.vcd");
        $dumpvars(0, tb_one_shot);
    end

    // ----------------- Scoreboard (aligned to registered outputs) -----------------
    integer cnt_non, cnt_re;
    reg     exp_y_non_q, exp_y_re_q;
    reg     trig_q;
    integer errors;

    // helper: absolute value for $random
    function integer abs_i;
        input integer v;
        begin abs_i = (v < 0) ? -v : v; end
    endfunction

    // Single checker tick each posedge
    always @(posedge clk) begin
        if (!rst_n) begin
            cnt_non      <= 0;
            cnt_re       <= 0;
            exp_y_non_q  <= 1'b0;
            exp_y_re_q   <= 1'b0;
            trig_q       <= 1'b0;
            errors       <= 0;
        end else begin
            // Compare DUT outputs against previous-cycle expectations
            if (y_non !== exp_y_non_q) begin
                $display("MISMATCH(NON) @%0t: exp=%0d got=%0d (cnt_non=%0d)", $time, exp_y_non_q, y_non, cnt_non);
                errors <= errors + 1;
            end
            if (y_retrig !== exp_y_re_q) begin
                $display("MISMATCH(RETRIG) @%0t: exp=%0d got=%0d (cnt_re=%0d)", $time, exp_y_re_q, y_retrig, cnt_re);
                errors <= errors + 1;
            end

            // Compute next expectations (mirror DUT semantics)
            // rising edge of trig
            // (use registered trig_q so it's aligned with DUT's edge detector)
            // trig_rise = trig & ~trig_q;
            if (trig & ~trig_q) begin
                // non-retriggerable
                if (cnt_non == 0) cnt_non <= PULSE_LEN;
                else              cnt_non <= (cnt_non > 0) ? (cnt_non - 1) : 0;

                // retriggerable
                cnt_re <= PULSE_LEN;
            end else begin
                // no new trigger
                if (cnt_non > 0) cnt_non <= cnt_non - 1;
                else             cnt_non <= 0;

                if (cnt_re  > 0) cnt_re  <= cnt_re  - 1;
                else             cnt_re  <= 0;
            end

            // Next expected y (registered like the DUT)
            exp_y_non_q <= ( (trig & ~trig_q) ? ((cnt_non==0)?PULSE_LEN:((cnt_non>0)?(cnt_non-1):0)) :
                             ((cnt_non>0)?(cnt_non-1):0) ) != 0;

            exp_y_re_q  <= ( (trig & ~trig_q) ? PULSE_LEN :
                             ((cnt_re>0)?(cnt_re-1):0) ) != 0;

            trig_q <= trig;
        end
    end

    // ----------------- Stimulus -----------------
    task pulse; input integer cycles;
        begin
            @(negedge clk); trig <= 1'b1;
            repeat (cycles) @(posedge clk);
            @(negedge clk); trig <= 1'b0;
        end
    endtask

    task idle; input integer cycles;
        begin
            @(negedge clk); trig <= 1'b0;
            repeat (cycles) @(posedge clk);
        end
    endtask

    // simple rand-range using $random (no $urandom_range)
    function integer rand_range;
        input integer lo, hi; integer r, span;
        begin
            span = hi - lo + 1;
            r = abs_i($random) % span;
            rand_range = lo + r;
        end
    endfunction

    initial begin
        // Reset
        trig = 1'b0; rst_n = 1'b0;
        repeat (5) @(posedge clk);
        rst_n = 1'b1;

        // P1) Single 1-cycle trigger
        pulse(1); repeat (PULSE_LEN+2) @(posedge clk);

        // P2) Dense triggers within active window
        pulse(1); repeat (2) @(posedge clk);
        pulse(1); repeat (2) @(posedge clk);
        pulse(1); repeat (PULSE_LEN+3) @(posedge clk);

        // P3) Well-spaced triggers (>= PULSE_LEN apart)
        idle(3);
        pulse(1); repeat (PULSE_LEN+1) @(posedge clk);
        pulse(1); repeat (PULSE_LEN+1) @(posedge clk);

        // P4) Random bursts
        begin : random_bursts
            integer k;
            for (k = 0; k < 40; k = k + 1) begin
                if (rand_range(0,1) == 1) pulse(rand_range(1,2)); // 1–2 high
                else                      idle (rand_range(1,4));  // 1–4 low
                @(posedge clk);
            end
        end

        // Report
        $display("====================================================");
        $display("Errors: %0d", errors);
        if (errors == 0) $display("RESULT: PASS");
        else             $display("RESULT: FAIL");
        $display("VCD written to one_shot.vcd");
        $display("====================================================");
        $finish;
    end

endmodule
