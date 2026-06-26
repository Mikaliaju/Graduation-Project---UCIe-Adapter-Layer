module UC_single_port_ram #(
    parameter DATA_WIDTH = 8,
    parameter ADDR_WIDTH = 6
)(
    input i_clk,
    input i_rst_n,
    input i_init,
    input we,
    input [ADDR_WIDTH-1:0] addr,
    input [DATA_WIDTH-1:0] din,
    output reg [DATA_WIDTH-1:0] dout
);
    // Declare the RAM array
    reg [DATA_WIDTH-1:0] ram [0:(1<<ADDR_WIDTH)-1];

    always @ (posedge i_clk or negedge i_rst_n) begin
        if (~i_rst_n || ~i_init) begin
            foreach (ram[i]) begin
                ram[i] <= '0;
            end
        end
        if (we) begin
            // Write operation
            ram[addr] <= din;
        end else begin
            // Read operation
            dout <= ram[addr];
        end
    end
endmodule
