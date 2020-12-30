module tb_top();
   parameter integer DATAW = 32;
   parameter integer ADDRW = 32;
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [DATAW-1:0]	prdata;			// From u_apb_slave of apb_slave.v
   // End of automatics
   /*AUTOREGINPUT*/
   // Beginning of automatic reg inputs (for undeclared instantiated-module inputs)
   reg			clk;			// To u_apb_slave of apb_slave.v
   reg [ADDRW-1:0]	paddr;			// To u_apb_slave of apb_slave.v
   reg			penable;		// To u_apb_slave of apb_slave.v
   reg			psel;			// To u_apb_slave of apb_slave.v
   reg [DATAW-1:0]	pwdata;			// To u_apb_slave of apb_slave.v
   reg			pwrite;			// To u_apb_slave of apb_slave.v
   reg			rst_n;			// To u_apb_slave of apb_slave.v
   // End of automatics
    			    
  			    
   reg [32:0] 	    _paddr;
   reg [7:0] 	    _op;
   reg [32:0] 	    _pdata;
   reg              _retval;

   apb_slave u_apb_slave(/*AUTOINST*/
			 // Outputs
			 .prdata		(prdata[DATAW-1:0]),
			 // Inputs
			 .clk			(clk),
			 .rst_n			(rst_n),
			 .paddr			(paddr[ADDRW-1:0]),
			 .pwrite		(pwrite),
			 .psel			(psel),
			 .penable		(penable),
			 .pwdata		(pwdata[DATAW-1:0]));


   initial begin
      clk = 1'b0;
      forever begin
         #5 clk = 1'b1;
	 #5 clk = 1'b0;
      end
   end
   
   initial begin
       $dumpfile("apb.vcd");
       $dumpvars(0, tb_top);
       $dumpon;
      rst_n = 1'b0;
      psel = 0;
      penable = 0;
      #50 rst_n = 1'b1;
   end

   task write_apb(input [31:0] addr,
	      input [31:0] data);
      begin
	 @(negedge clk);
	 paddr <= addr;
	 psel <= 1;
	 pwrite <= 1;
	 pwdata <= data;
	 @(negedge clk);
	 penable <= 1;
	 @(negedge clk);
	 psel <= 0;
	 penable <= 0;
      end
   endtask // write

    task read_apb(input [31:0] addr);
       begin
	  @(negedge clk);
	  paddr <= addr;
	  psel <= 1;
	  pwrite <= 0;
	  @(negedge clk);
	  penable <= 1;
	  @(negedge clk);
	  _pdata = prdata;
	  psel    <= 0;
	  penable <= 0;
       end
    endtask // read


   initial begin: bfm_apb
      #100;	// let the reset settle
      forever begin
	 while (rst_n == 1'b0) begin
	    @(posedge clk);
	 end // while (rst_n == 1'b0)
	 
	 @(negedge clk);
	 case($apb_try_next_item(_paddr, _pdata, _op))
	   0: begin: valid_transation
	      if(_op == 0) begin
		 $display("##### WRITE %x: @%x", _pdata, _paddr);
		 write_apb(_paddr, _pdata);
	      end // if (_op ==1)
	      else begin
		 $display("##### READ: @%x", _paddr);
		 read_apb(_paddr);
	      end // else: !if(_op == 0)
	      if ($apb_put(_paddr,_pdata,_op));
	      if ($apb_item_done(0) != 0) ; // $finish;
	   end // block: valid_transation
	   default: begin: idle_transation
	   end // block: idle_transation
	 endcase // case ($apb_try_next_item(_paddr, _pdata, _op))
	 
	 
      end // forever begin
   end // block: bfm
   
   
endmodule

// Local Variables:
// verilog-library-directories:("." "../rtl/")
// verilog-library-files:()
// verilog-library-extensions:(".v")
// verilog-auto-inst-param-value:t                                                  
// End:
