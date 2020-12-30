module apb_slave #(parameter ADDRW = 32, DATAW = 32)
  (
  input 		   clk,
  input 		   rst_n,
  input [ADDRW-1:0] 	   paddr,
  input 		   pwrite,
  input 		   psel,
  input 		   penable,
  input [DATAW-1:0] 	   pwdata,
  output reg [DATAW-1:0] prdata
  );

  // reg [DATAW-1:0] 	   mem [256];
  reg [DATAW-1:0]  reg1;
  reg [DATAW-1:0]  reg2;
  reg [DATAW-1:0]  reg3;
  reg [DATAW-1:0]  reg4;
  reg [DATAW-1:0]  reg5;
  reg [DATAW-1:0]  reg6;
  reg [DATAW-1:0]  reg7;
  reg [DATAW-1:0]  reg8;
  reg [DATAW-1:0]  reg9;
  reg [DATAW-1:0]  reg10;

// Fields
  reg [1:0]   reg1_f1; //RO
  reg         reg1_f2; //RO
  reg         reg1_f3; //RO
  reg [27:0]  reg1_f4;
  reg [3:0]   reg2_f1;
  reg         reg2_f2;
  reg [26:0]  reg2_f3;
  reg [1:0]   reg3_f1; //RO
  reg [14:0]  reg3_f2;
  reg [14:0]  reg3_f3;
  reg [15:0]  reg4_f1;
  reg [15:0]  reg4_f2;
  reg [31:0]  reg5_f1;
  reg         reg6_f1;
  reg [2:0]   reg6_f2;
  reg [6:0]   reg6_f3;
  reg [12:0]  reg6_f4;
  reg [5:0]   reg6_f5;
  reg         reg7_f1;
  reg         reg7_f2;
  reg [29:0]  reg7_f3;
  reg [7:0]   reg8_f1; //WO
  reg [23:0]  reg8_f2; //WO
  reg [9:0]   reg9_f1;
  reg [9:0]   reg9_f2;
  reg [11:0]  reg9_f3;
  reg         reg10_f1;
  reg         reg10_f2;
  reg [29:0]  reg10_f3;

  reg [1:0] 		   apb_st;

  parameter logic [1:0]   SETUP = 0;
  parameter logic [1:0]   W_ENABLE = 1;
  parameter logic [1:0]   R_ENABLE = 2;

  // SETUP -> ENABLE
  always @(negedge rst_n or posedge clk) begin
    if (rst_n == 0) begin
      apb_st <= 0;
      prdata <= 0;
      reg1_f1 <= 2'b0;
      reg1_f2 <= 1'd1;
      reg1_f3 <= 1'd1;
      reg1_f4 <= 0;
      reg2_f1 <= 0;
      reg2_f2 <= 0;
      reg2_f3 <= 1'd1;
      reg3_f1 <= 1'd1;
      reg3_f2 <= 0;
      reg3_f3 <= 0;
      reg4_f1 <= 1'd1;
      reg4_f2 <= 16'd66;
      reg5_f1 <= 0;
      reg6_f1 <= 0;
      reg6_f2 <= 3'd2;
      reg6_f3 <= 7'd83;
      reg6_f4 <= 13'd3072;
      reg6_f5 <= 6'd36;
      reg7_f1 <= 0;
      reg7_f2 <= 1'd1;
      reg7_f3 <= 1'd1;
      reg8_f1 <= 0;
      reg8_f2 <= 0;
      reg9_f1 <= 0;
      reg9_f2 <= 0;
      reg9_f3 <= 0; 
      reg10_f1 <= 1'd1;
      reg10_f2 <= 1'd1;
      reg10_f3 <= 30'd32;
    end
    else begin
      case (apb_st)
      SETUP : begin
            // clear the prdata
            prdata <= 0;

            // Move to ENABLE when the psel is asserted
            if (psel && !penable) begin
              if (pwrite) begin
                apb_st <= W_ENABLE;
              end

              else begin
              apb_st <= R_ENABLE;
              end
            end
          end
      W_ENABLE : begin
            // write pwdata to memory
            if (psel && penable && pwrite) begin
              // mem[paddr] <= pwdata;
              case (paddr)
                32'h00000000:begin 
                  reg1_f4 <= pwdata[27:0];
                  reg1 <= {reg1_f1,reg1_f2,reg1_f3,reg1_f4};
                end 
                32'h00000004:begin
                  reg2_f1 <= pwdata[31:28];
                  reg2_f2 <= pwdata[27];
                  reg2_f3 <= pwdata[26:0];
                  reg2 <= {reg2_f1,reg2_f2,reg2_f3};
                end
                32'h00000008:begin 
                  reg3_f2 <= pwdata[29:15];
                  reg3_f3 <= pwdata[14:0];
                  reg3 <= {reg3_f1,reg3_f2,reg3_f3};
                end
                32'h0000000C:begin
                  reg4_f1 <= pwdata[31:16];
                  reg4_f2 <= pwdata[15:0];
                  reg4 <= {reg4_f1,reg4_f2};
                end
                32'h00000010:begin 
                  reg5_f1 <= pwdata;
                  reg5 <= reg5_f1;
                end
                32'h00000014:begin 
                  reg6_f1 <= pwdata[31];
                  reg6_f2 <= pwdata[28:26];
                  reg6_f3 <= pwdata[25:19];
                  reg6_f4 <= pwdata[18:6];
                  reg6_f5 <= pwdata[5:0];
                  reg6 <= {reg6_f1,2'b0,reg6_f2,reg6_f3,reg6_f4,reg6_f5};
                end
                32'h00000018:begin 
                  reg7_f1 <= pwdata[31];
                  reg7_f2 <= pwdata[30];
                  reg7_f3 <= pwdata[29:0];
                  reg7 <= {reg7_f1,reg7_f2,reg7_f3};
                end
                32'h0000001C:begin 
                  reg8_f1 <= pwdata[31:24];
                  reg8_f2 <= pwdata[23:0];
                  reg8 <= {reg8_f1,reg8_f2};
                end
                32'h00000020:begin 
                  reg9_f1 <= pwdata[31:22];
                  reg9_f2 <= pwdata[21:12];
                  reg9_f3 <= pwdata[11:0];
                  reg9 <= {reg9_f1,reg9_f2,reg9_f3};
                end
                32'h00000024:begin 
                  reg10_f1 <= pwdata[31];
                  reg10_f2 <= pwdata[30];
                  reg10_f3 <= pwdata[29:0];
                  reg10 <= {reg10_f1,reg10_f2,reg10_f3};
                end
              endcase
            end
            // return to SETUP
            apb_st <= SETUP;
        end //END Begin of W_ENABLE
      R_ENABLE : begin
            // read prdata from memory
            if (psel && penable && !pwrite) begin
              // prdata <= mem[paddr];
              case (paddr)
                32'h00000000:begin 
                  prdata[31:30] <= reg1_f1;
                  prdata[29]    <= reg1_f2;
                  prdata[28]    <= reg1_f3;
                  prdata[27:0]  <= reg1_f4;
                end
                32'h00000004:begin 
                  prdata[31:28] <= reg2_f1;
                  prdata[27]    <= reg2_f2;
                  prdata[26:0]  <= reg2_f3;
                end
                32'h00000008:begin 
                  prdata[31:30] <= reg3_f1;
                  prdata[29:15] <= reg3_f2;
                  prdata[14:0]  <= reg3_f3;
                end
                32'h0000000C:begin
                  prdata[31:16] <= reg4_f1;
                  prdata[15:0]  <= reg4_f2;
                end
                32'h00000010:begin 
                  prdata <= reg5_f1;
                end
                32'h00000014:begin 
                  prdata[31]    <= reg6_f1;
                  prdata[30:29] <= 2'b0;
                  prdata[28:26] <= reg6_f2;
                  prdata[25:19] <= reg6_f3;
                  prdata[18:6]  <= reg6_f4;
                  prdata[5:0]   <= reg6_f5;
                end
                32'h00000018:begin 
                  prdata[31]  <= reg7_f1;
                  prdata[30]  <= reg7_f2;
                  prdata[29:0]<= reg7_f3;
                end
                // 32'h0000001C:begin //This address is write only 
                // end
                32'h00000020:begin 
                  prdata[31:22] <= reg9_f1;
                  prdata[21:12] <= reg9_f2;
                  prdata[11:0]  <= reg9_f3;
                end
                32'h00000024:begin 
                  prdata[31]  <= reg10_f1;
                  prdata[30]  <= reg10_f2;
                  prdata[29:0]<= reg10_f3;
                end
              endcase
            end
            // return to SETUP
            apb_st <= SETUP;
          end
      endcase
    end
  end
endmodule