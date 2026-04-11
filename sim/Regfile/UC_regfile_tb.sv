
module UC_regfile_tb;

  // Parameters

  //Ports
  reg i_init;
  reg i_clk;
  reg i_rst_n;
  reg [3:0] row;
  reg [4:0] column;
  logic data [31:0];
  wire wanted_bit[31:0];

  UC_regfile  UC_regfile_inst (
    .i_init(i_init),
    .i_clk(i_clk),
    .i_rst_n(i_rst_n),
    .row(row),
    .column(column),
    .data(data),
    .wanted_bit(wanted_bit)
  );

initial begin
  i_clk = 0;
  forever begin
    #10
    i_clk = ~i_clk;
  end
end

initial begin
  i_rst_n = 'b0;
  i_init = 'b0;
  data = '{default:'b0};
  @(negedge i_clk);
  i_rst_n = 'b1;
  i_init = 'b1;
  data = {default:'hf};

  row = 'd3;
  column = 'd5;
  data = '{32{'b1}};
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  @(negedge i_clk);
  $stop;
  $finish;
end
endmodule