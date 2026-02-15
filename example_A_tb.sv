`timescale 1ns/1ps

// -----------------------------------------------------------------------------
// 1. Reference Module (Golden Model)
//    This implements the "Double Dabble" algorithm behaviorally to check correctness.
// -----------------------------------------------------------------------------
module reference_module(
    input [4:0] binary_input,
    output reg [7:0] bcd_output
);
    integer i;
    reg [12:0] temp; // 13-bit register as per algorithm specs

    always @(*) begin
        // Initialize
        temp = 0;
        temp[4:0] = binary_input;

        // Loop 5 times (Double Dabble)
        for (i = 0; i < 5; i = i + 1) begin
            // Add 3 to columns >= 5
            if (temp[12:9] >= 5) temp[12:9] = temp[12:9] + 3;
            if (temp[8:5]  >= 5) temp[8:5]  = temp[8:5]  + 3;
            
            // Shift left 1
            temp = temp << 1;
        end
        
        // Assign output
        bcd_output = temp[12:5];
    end
endmodule

// -----------------------------------------------------------------------------
// 2. Stimulus Generator
//    Generates inputs for both DUT and Reference
// -----------------------------------------------------------------------------
module stimulus_gen (
    input clk,
    output reg [4:0] binary_input
);

    initial begin
        binary_input = 0;
        
        // Test all possible 5-bit values (0 to 31)
        repeat(32) @(negedge clk) begin
            binary_input = binary_input + 1;
        end
        
        // Random testing for robustness
        repeat(20) @(negedge clk) begin
            binary_input = $random;
        end
        
        #10 $finish;
    end
endmodule

// -----------------------------------------------------------------------------
// 3. Top-Level Testbench
//    Connects Stimulus -> DUT & Reference -> Comparator
// -----------------------------------------------------------------------------
module tb();

    // -- Signal Declarations --
    reg clk = 0;
    wire [4:0] binary_input;
    
    // Outputs
    wire [7:0] bcd_ref;  // From Golden Model
    wire [7:0] bcd_dut;  // From Your Design (DUT)

    // Statistics
    int errors = 0;
    int clocks = 0;
    int errortime = 0;

    // -- Clock Generation --
    initial forever #5 clk = ~clk;

    // -- Instantiations --

    // 1. Stimulus Generator
    stimulus_gen stim (
        .clk(clk),
        .binary_input(binary_input)
    );

    // 2. Reference Model (Golden)
    reference_module ref_mod (
        .binary_input(binary_input),
        .bcd_output(bcd_ref)
    );

    // 3. Device Under Test (Your AutoChip generated module)
    //    Note: AutoChip will name the module 'binary_to_bcd_converter' 
    //    or 'top_module' depending on your prompt.
    //    Based on your config.json, it expects 'top_module'.
    top_module dut (
        .binary_input(binary_input),
        .bcd_output(bcd_dut)
    );

    // -- Verification Logic --
    
    // Setup VCD dumping for waveforms
    initial begin 
        $dumpfile("wave.vcd");
        $dumpvars(0, tb);
    end

    // Compare Outputs on Negative Edge (allows combinatorial logic to settle)
    always @(negedge clk) begin
        clocks++;
        
        // Comparison: Check if DUT matches Reference
        if (bcd_dut !== bcd_ref) begin
            if (errors == 0) errortime = $time;
            errors++;
            $display("Mismatch at time %0t: Input=%d | Expected BCD=%h | Got BCD=%h", 
                     $time, binary_input, bcd_ref, bcd_dut);
        end
    end

    // Final Report
    final begin
        if (errors == 0) begin
            $display("Simulation passed! No mismatches.");
            $display("Mismatches: 0 in %0d samples", clocks);
        end else begin
            $display("Simulation failed.");
            $display("Mismatches: %0d in %0d samples", errors, clocks);
            $display("First mismatch at time: %0d", errortime);
        end
    end

endmodule