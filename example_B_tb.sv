`timescale 1 ps/1 ps

// -----------------------------------------------------------------------------
// Reference Module (Golden Model)
// Uses a shift register to verify the sequence behaviorally.
// Sequence: 1 -> 5 -> 6 -> 0 -> 6 -> 6 -> 3 -> 5
// -----------------------------------------------------------------------------
module reference_module(
    input clk,
    input reset_n,
    input [2:0] data,
    output reg sequence_found
);
    // Store last 8 inputs (8 * 3 bits = 24 bits)
    reg [23:0] history;
    
    // The target sequence (Newest data is LSB, Oldest is MSB)
    // Sequence order: 1, 5, 6, 0, 6, 6, 3, 5
    // We compare: {oldest ... newest}
    // So the vector looks like: {1, 5, 6, 0, 6, 6, 3, 5}
    localparam [23:0] TARGET_SEQ = {3'd1, 3'd5, 3'd6, 3'd0, 3'd6, 3'd6, 3'd3, 3'd5};

    always @(posedge clk or negedge reset_n) begin
        if (!reset_n) begin
            history <= 24'b0;
            sequence_found <= 0;
        end else begin
            // Shift in new data from the right (LSB)
            history <= {history[20:0], data};
            
            // Check if the NEW history (including current data) matches
            if ({history[20:0], data} == TARGET_SEQ)
                sequence_found <= 1;
            else
                sequence_found <= 0;
        end
    end
endmodule

// -----------------------------------------------------------------------------
// Stimulus Generator
// -----------------------------------------------------------------------------
module stimulus_gen (
    input clk,
    output reg reset_n,
    output reg [2:0] data,
    output reg[511:0] wavedrom_title,
    output reg wavedrom_enable
);

    task wavedrom_start(input[511:0] title = "");
    endtask
    
    task wavedrom_stop;
        #1;
    endtask    

    // Helper task to feed a value
    task send_data(input [2:0] val);
        @(posedge clk);
        data <= val;
    endtask

    initial begin
        data <= 0;
        reset_n <= 0;
        wavedrom_start("Sequence Detector");
        
        // 1. Reset
        repeat(5) @(posedge clk);
        reset_n <= 1; // Release reset
        
        // 2. Send Random Noise
        repeat(5) @(posedge clk) data <= $random;

        // 3. Send the CORRECT Sequence
        // 1 -> 5 -> 6 -> 0 -> 6 -> 6 -> 3 -> 5
        send_data(1);
        send_data(5);
        send_data(6);
        send_data(0);
        send_data(6);
        send_data(6);
        send_data(3);
        send_data(5); // Output should go high here!

        // 4. Send some noise again
        repeat(3) @(posedge clk) data <= $random;
        
        // 5. Send Sequence again (to check re-entry)
        send_data(1);
        send_data(5);
        send_data(6);
        send_data(0);
        send_data(6);
        send_data(6);
        send_data(3);
        send_data(5); 

        wavedrom_stop();
        
        // 6. Long random test
        repeat(100) @(posedge clk) data <= $random;
        
        #10 $finish;
    end
    
endmodule

// -----------------------------------------------------------------------------
// Top Level Testbench
// -----------------------------------------------------------------------------
module tb();

    typedef struct packed {
        int errors;
        int errortime;
        int clocks;
    } stats;
    
    stats stats1;
    
    wire[511:0] wavedrom_title;
    wire wavedrom_enable;
    
    reg clk=0;
    initial forever #5 clk = ~clk;

    logic reset_n;
    logic [2:0] data;
    logic found_ref;
    logic found_dut;

    initial begin 
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
    end

    wire tb_match;      
    wire tb_mismatch = ~tb_match;
    
    stimulus_gen stim1 (
        .clk(clk),
        .reset_n(reset_n),
        .data(data),
        .wavedrom_title(wavedrom_title),
        .wavedrom_enable(wavedrom_enable)
    );

    reference_module good1 (
        .clk(clk),
        .reset_n(reset_n),
        .data(data),
        .sequence_found(found_ref)
    );
        
    top_module top_module1 (
        .clk(clk),
        .reset_n(reset_n),
        .data(data),
        .sequence_found(found_dut)
    );

    // Verification Logic
    assign tb_match = (found_ref === found_dut);

    always @(posedge clk) begin
        // Only check after reset is released
        if (reset_n) begin
            stats1.clocks++;
            
            // Allow for a 1-cycle mismatch if the DUT registers the output 
            // differently than the reference, but usually both should align 
            // on the clock edge if designed as a Moore/Mealy properly.
            // We check strictly here.
            
            if (!tb_match) begin
                if (stats1.errors == 0) stats1.errortime = $time;
                stats1.errors++;
                $display("Mismatch at time %0t: Data=%d | Expected Found=%b | Got Found=%b", 
                         $time, data, found_ref, found_dut);
            end
        end
    end

    final begin
        if (stats1.errors == 0) 
            $display("Simulation passed! No mismatches.");
        else 
            $display("Simulation failed. Total mismatches: %0d", stats1.errors);
            
        $display("Simulation finished at %0d ps", $time);
    end
endmodule