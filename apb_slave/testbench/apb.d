import esdl;
import uvm;
import std.stdio;
import std.string: format;
import std.bitmanip: swapEndian;
///////////////
import std.file;
// /// // ///////
import std.socket;

import esdl.intf.hal;

enum kind_e: ubyte {WRITE, READ, IDLE, DONE,
    WRITE_RSP, READ_RSP, IDLE_RSP, DONE_RSP};

alias apb32_rw = apb_rw!(32, 32);

class apb_rw(uint ADDRW, uint DATAW): uvm_sequence_item
{
  @UVM_DEFAULT {
    @rand UBit!ADDRW addr;
    @rand UBit!DATAW data;
    @rand kind_e kind;

    bool error;
  }
 
  mixin uvm_object_utils;
   
  this(string name = "apb_rw") {
    super(name);
  }

  Constraint! q{
    addr < 256;
  } addr_range;


  override void do_vpi_put(uvm_vpi_iter iter) {
    iter.put_values(addr, data, kind);
  }

  override void do_vpi_get(uvm_vpi_iter iter) {
    iter.get_values(addr, data, kind);
  }
}

class apb_monitor: uvm_monitor
{
  // qemu_seq_item qemu_item;
  
  @UVM_BUILD {
    uvm_analysis_imp!(write) apb_analysis;
    // uvm_analysis_port!qemu_seq_item qemu_port;
  }

  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  void write(apb_rw!(32, 32) item) {
    uvm_info("APB MONITOR", format("\n%s", item.sprint()), UVM_DEBUG);
  }
}

class apb_fifo_seq(uint ADDRW, uint DATAW): apb_seq!(ADDRW, DATAW)
{
  mixin uvm_object_utils;

  this(string name="") {
    super(name);
  }

  bool _swapRequired;
  ushort _version;
  uint _id;
  
  
  struct TrHeader {
    align(1):
    ubyte endian;
    uint pkt_len;
    ushort ver;
    uint id;
    kind_e op;
    uint status;
  }

  struct rb_fields {
    align(1):
    uint length;
    ulong addr;
    uint data;
  }

  rb_fields* read_data(File fifo, uint size) {
    ubyte[] trSizeBuf;
    trSizeBuf.length = size;
    fifo.rawRead(trSizeBuf);

    //
    rb_fields* rb_f;

    rb_f = cast(rb_fields*)trSizeBuf.ptr;

    if (_swapRequired) {
      rb_f.length = swapEndian(rb_f.length);
      rb_f.addr = swapEndian(rb_f.addr);
      rb_f.data = swapEndian(rb_f.data);
    }
  
    writeln("rb_f is : ", *rb_f);
    return rb_f;
  }
  
  bool get_req_from_fifo(File fifo) {

    ubyte[16] rawTrHeader;
    TrHeader* trHeader;

	
    writeln("Waiting for data from fifo");
    fifo.rawRead(rawTrHeader);

    trHeader = cast(TrHeader*) rawTrHeader;

    writeln("Read data from fifo");

    version(LittleEndian) {
      if (trHeader.endian == 0xF0) {
	_swapRequired = true;
      }
      else if (trHeader.endian != 0x0F) {
	writefln("Expected Delimiter 0x0F or 0xF0; got 0x%x",
		 trHeader.endian);
      }
    }
    version(BigEndian) {
      if (trHeader.endian == 0x0F) {
	_swapRequired = true;
      }
      else if (trHeader.endian != 0xF0) {
	writefln("Expected Delimiter 0x0F or 0xF0; got 0x%x",
		 trHeader.endian);
      }
    }

    uint pkt_len = trHeader.pkt_len;
    if (_swapRequired) {
      pkt_len = swapEndian(pkt_len);
    }

    _version = trHeader.ver;
    if (_swapRequired) {
      _version = swapEndian(_version);
    }
	  
    _id = trHeader.id;
    if (_swapRequired) {
      _id = swapEndian(_id);
    }
	  
    writeln("rawTrHeader is: ", rawTrHeader);
    writeln("trHeader is: ", trHeader);
    writeln("Packet length is: ", pkt_len);

    this._kind = cast(kind_e) trHeader.op;

    if (this._kind == kind_e.WRITE)
      {
	rb_fields* rb_f = read_data(fifo, pkt_len);
	writeln("inside write of req_thread");
	this._addr = cast(UBit!8) rb_f.addr.toBitVec ;
	this._data = cast(UBit!32) rb_f.data.toBitVec;
	writeln("Write Data is: ", rb_f.data);
	writeln("Write Data is: ", rb_f.data.toBitVec);
	writeln(this.sprint);
      }
    else if (this._kind == kind_e.READ)
      {
	rb_fields* rb_f = read_data(fifo, pkt_len);
	writeln("inside read of request thread");
	this._addr = cast(UBit!8) rb_f.addr.toBitVec ;
	// this._data = cast(UBit!32) rb_f.data.toBitVec;
	writeln(this.sprint);
      }
    else if (this._kind == kind_e.IDLE)
      {
	writeln("inside idle of this");
	this._addr = 0;
	this._data = 0;
	writeln(this.sprint);
      }
    else if (this._kind == kind_e.DONE)
      {
	writeln("inside terminate of this");
	writeln(this.sprint);
	return false;
      }

    return true;
  }

  bool put_rsp_to_fifo(File fifo) {
    union Header {
      ubyte[16] _bytes;
      TrHeader _fields;
    }

    Header header;

    union Payload {
      ubyte[16] _bytes;
      rb_fields _fields;
    }

    Payload payload;

    header._fields.endian = 0x0f;
    header._fields.ver = _version;
    header._fields.id = _id;
    header._fields.pkt_len = 16;
    header._fields.status = 0;

    switch (this._kind) {
    case kind_e.WRITE:
      header._fields.pkt_len = 16;
      header._fields.op = kind_e.WRITE_RSP;
      fifo.rawWrite(header._bytes);
      payload._fields.length = 4;
      payload._fields.addr = this._addr;
      payload._fields.data = this._data;
      fifo.rawWrite(payload._bytes);
      break;
    case kind_e.READ:
      header._fields.pkt_len = 16;
      header._fields.op = kind_e.READ_RSP;
      fifo.rawWrite(header._bytes);
      payload._fields.length = 4;
      payload._fields.addr = this._addr;
      payload._fields.data = this._data;
      fifo.rawWrite(payload._bytes);
      break;
    case kind_e.IDLE:
      assert(false);
    case kind_e.DONE:
      header._fields.pkt_len = 0;
      header._fields.op = kind_e.DONE_RSP;
      fifo.rawWrite(header._bytes);
      break;
    default: assert(false);
    }
    return true;
  }

  // task
  override void body() {
    import std.stdio;

    // uvm_info("apb_seq", "Starting sequence", UVM_MEDIUM);
    req = apb32_rw.type_id.create("req_" ~ get_name);
    // atomic sequence
    // uvm_create(req);

    req.kind = _kind;
    req.addr = _addr;
    req.data = _data;

    // apb32_rw cloned = cast(apb_rw) req.clone;
    start_item(req);
    finish_item(req);
    
    uvm_info("APB SEQ", format("\n%s", req.sprint()), UVM_DEBUG);
    writeln("I AM HERE");
    _data = req.data; 
    File rdata = File("/home/utk/Intern_Project/Interactive-Register-Debugging/apb_slave/testbench/data.txt","a+");
    rdata.writeln(_data);
    @trusted void flush();
    //string line = rdata.readln();
    //writeln(line);
    //rdata.close();
    // uvm_info("apb_rw", "Finishing sequence", UVM_MEDIUM);
  } // body

}

class apb_socket_seq(uint ADDRW, uint DATAW): apb_seq!(ADDRW, DATAW)
{
  
  mixin uvm_object_utils;

  this(string name="") {
    super(name);
  }

  bool _swapRequired;
  ushort _version;
  uint _id;
  
  
  struct TrHeader {
    align(1):
    ubyte endian;
    uint pkt_len;
    ushort ver;
    uint id;
    kind_e op;
    uint status;
  }

  struct rb_fields {
    align(1):
    uint length;
    ulong addr;
    uint data;
  }

  rb_fields* read_data(Socket socket, uint size) {
    ubyte[] trSizeBuf;
    ubyte[] buffer;
    
    // trSizeBuf.length = size;

    while (trSizeBuf.length < size) {
      buffer.length = size - trSizeBuf.length;
      auto ret = socket.receive(buffer);
      if (ret == Socket.ERROR)
	uvm_fatal("SOCKET", "Error receiving data from socket");
      if (ret == 0)
	uvm_fatal("SOCKET", "Got insufficient bytes for TrHeader");
      // now slice the buffer to get the part...
      trSizeBuf ~= buffer[0 .. ret];
    }
    
    //
    rb_fields* rb_f;

    rb_f = cast(rb_fields*)trSizeBuf.ptr;

    if (_swapRequired) {
      rb_f.length = swapEndian(rb_f.length);
      rb_f.addr = swapEndian(rb_f.addr);
      rb_f.data = swapEndian(rb_f.data);
    }
  
    writeln("rb_f is : ", *rb_f);
    return rb_f;
  }
  
  bool get_req_from_socket(Socket socket) {

    ubyte[] rawTrHeader;
    ubyte[] buffer;

    writeln("Waiting for data from socket");
    while (rawTrHeader.length < 16) {
      import std.string: format;

      buffer.length = 16 - rawTrHeader.length;
      auto ret = socket.receive(buffer);
      uvm_info("SOCKET", format("Received %d bytes from socket", ret),
	       UVM_DEBUG);
      if (ret == Socket.ERROR)
	uvm_fatal("SOCKET", "Error receiving data from socket");
      if (ret == 0)
	uvm_fatal("SOCKET", "Got insufficient bytes for TrHeader");
      // now slice the buffer to get the part...
      rawTrHeader ~= buffer[0 .. ret];
    }
    
    TrHeader* trHeader;

    trHeader = cast(TrHeader*) rawTrHeader;

    writeln("Read data from socket");

    version(LittleEndian) {
      if (trHeader.endian == 0xF0) {
	_swapRequired = true;
      }
      else if (trHeader.endian != 0x0F) {
	writefln("Expected Delimiter 0x0F or 0xF0; got 0x%x",
		 trHeader.endian);
      }
    }
    version(BigEndian) {
      if (trHeader.endian == 0x0F) {
	_swapRequired = true;
      }
      else if (trHeader.endian != 0xF0) {
	writefln("Expected Delimiter 0x0F or 0xF0; got 0x%x",
		 trHeader.endian);
      }
    }

    uint pkt_len = trHeader.pkt_len;
    if (_swapRequired) {
      pkt_len = swapEndian(pkt_len);
    }

    _version = trHeader.ver;
    if (_swapRequired) {
      _version = swapEndian(_version);
    }
	  
    _id = trHeader.id;
    if (_swapRequired) {
      _id = swapEndian(_id);
    }
	  
    writeln("rawTrHeader is: ", rawTrHeader);
    writeln("trHeader is: ", trHeader);
    writeln("Packet length is: ", pkt_len);

    this._kind = cast(kind_e) trHeader.op;

    if (this._kind == kind_e.WRITE)
      {
	rb_fields* rb_f = read_data(socket, pkt_len);
	writeln("inside write of req_thread");
	this._addr = cast(UBit!8) rb_f.addr.toBitVec ;
	this._data = cast(UBit!32) rb_f.data.toBitVec;
	writeln("Write Data is: ", rb_f.data);
	writeln("Write Data is: ", rb_f.data.toBitVec);
	writeln(this.sprint);
      }
    else if (this._kind == kind_e.READ)
      {
	rb_fields* rb_f = read_data(socket, pkt_len);
	writeln("inside read of request thread");
	this._addr = cast(UBit!8) rb_f.addr.toBitVec ;
	// this._data = cast(UBit!32) rb_f.data.toBitVec;
	writeln(this.sprint);
      }
    else if (this._kind == kind_e.IDLE)
      {
	writeln("inside idle of this");
	this._addr = 0;
	this._data = 0;
	writeln(this.sprint);
      }
    else if (this._kind == kind_e.DONE)
      {
	writeln("inside terminate of this");
	writeln(this.sprint);
	return false;
      }

    return true;
  }

  bool put_rsp_to_socket(Socket socket) {
    union Header {
      ubyte[16] _bytes;
      TrHeader _fields;
    }

    Header header;

    union Payload {
      ubyte[16] _bytes;
      rb_fields _fields;
    }

    Payload payload;

    header._fields.endian = 0x0f;
    header._fields.ver = _version;
    header._fields.id = _id;
    header._fields.pkt_len = 16;
    header._fields.status = 0;

    switch (this._kind) {
    case kind_e.WRITE:
      header._fields.pkt_len = 16;
      header._fields.op = kind_e.WRITE_RSP;
      ubyte[] resp = header._bytes[];
      while (resp.length > 0) {
	auto ret = socket.send(resp);
	if (ret == Socket.ERROR)
	  uvm_fatal("SOCKET", "Exception sending response to socket");
	if (ret == 0)
	  uvm_fatal("SOCKET", "While responding, socket is closed");
	resp = resp[ret .. $];
      }
      payload._fields.length = 4;
      payload._fields.addr = this._addr;
      payload._fields.data = this._data;
      ubyte[] data = payload._bytes[];
      while (data.length > 0) {
	auto ret = socket.send(data);
	if (ret == Socket.ERROR)
	  uvm_fatal("SOCKET", "Exception sending response to socket");
	if (ret == 0)
	  uvm_fatal("SOCKET", "While responding, socket is closed");
	data = data[ret .. $];
      }
      break;
    case kind_e.READ:
      header._fields.pkt_len = 16;
      header._fields.op = kind_e.READ_RSP;
      ubyte[] resp = header._bytes[];
      while (resp.length > 0) {
	auto ret = socket.send(resp);
	if (ret == Socket.ERROR)
	  uvm_fatal("SOCKET", "Exception sending response to socket");
	if (ret == 0)
	  uvm_fatal("SOCKET", "While responding, socket is closed");
	resp = resp[ret .. $];
      }
      payload._fields.length = 4;
      payload._fields.addr = this._addr;
      payload._fields.data = this._data;
      ubyte[] data = payload._bytes[];
      while (data.length > 0) {
	auto ret = socket.send(data);
	if (ret == Socket.ERROR)
	  uvm_fatal("SOCKET", "Exception sending response to socket");
	if (ret == 0)
	  uvm_fatal("SOCKET", "While responding, socket is closed");
	data = data[ret .. $];
      }
      break;
    case kind_e.IDLE:
      assert(false);
    case kind_e.DONE:
      header._fields.pkt_len = 0;
      header._fields.op = kind_e.DONE_RSP;
      ubyte[] resp = header._bytes[];
      while (resp.length > 0) {
	auto ret = socket.send(resp);
	if (ret == Socket.ERROR)
	  uvm_fatal("SOCKET", "Exception sending response to socket");
	if (ret == 0)
	  uvm_fatal("SOCKET", "While responding, socket is closed");
	resp = resp[ret .. $];
      }
      break;
    default: assert(false);
    }
    return true;
  }

  // task
  override void body() {
    import std.stdio;

    // uvm_info("apb_seq", "Starting sequence", UVM_MEDIUM);
    req = apb32_rw.type_id.create("req_" ~ get_name);
    // atomic sequence
    // uvm_create(req);

    req.kind = _kind;
    req.addr = _addr;
    req.data = _data;

    // apb32_rw cloned = cast(apb_rw) req.clone;
    start_item(req);
    finish_item(req);

    uvm_info("APB SEQ", format("\n%s", req.sprint()), UVM_DEBUG);
    
    _data = req.data;
    
    // uvm_info("apb_rw", "Finishing sequence", UVM_MEDIUM);
  } // body

}
class apb_seq(uint ADDRW, uint DATAW): uvm_sequence!(apb_rw!(ADDRW, DATAW))
{
  mixin uvm_object_utils;

  apb_rw!(32, 32) req;
  apb_rw!(32, 32) rsp;
  qemu_seq_item qemu_rw;
  apb_sequencer sequencer;

  @UVM_DEFAULT {
    @rand UBit!DATAW _data;
    @rand UBit!ADDRW _addr;

    @rand kind_e _kind;
  }

  void set_read(ubyte addr) {
    _kind = kind_e.READ;
    _addr = addr;
  }

  void set_write(ubyte addr, ubyte data) {
    _kind = kind_e.WRITE;
    _addr = addr;
    _data = data;
  }
  
  this(string name="") {
    super(name);
  }

  // task
  override void body() {
    import std.stdio;

    // uvm_info("apb_seq", "Starting sequence", UVM_MEDIUM);
    req = apb_rw!(32, 32).type_id.create("req_" ~ get_name);
    // atomic sequence
    // uvm_create(req);

    req.kind = _kind;
    req.addr = _addr;
    req.data = _data;

    // apb_rw cloned = cast(apb_rw) req.clone;
    start_item(req);
    finish_item(req);

    // uvm_info("apb_rw", "Finishing sequence", UVM_MEDIUM);
  } // body

}


class qemu_seq_item: uvm_sequence_item
{
  mixin uvm_object_utils;
   
  @UVM_DEFAULT {
    @rand ubyte  data;
  }
 
  this(string name = "qemu_seq_item") {
    super(name);
  }

  // override public string convert2string() {
  //   if(kind == kind_e.WRITE)
  //     return format("kind=%s addr=%x data=%x",
  // 		    kind, addr, data);
  //   else
  //     return format("kind=%s addr=%x data=%x",
  // 		    kind, addr, data);
  // }

  void postRandomize() {
    // writeln("post_randomize: ", this.convert2string);
  }
}

class qemu_seq: uvm_sequence!qemu_seq_item
{
  mixin uvm_object_utils;

  qemu_seq_item req;
  qemu_seq_item rsp;
  qemu_sequencer sequencer;

  this(string name="") {
    super(name);
  }

  // task
  override void body() {
      // uvm_info("qemu_seq", "Starting sequence", UVM_MEDIUM);
      req = qemu_seq_item.type_id.create("req_" ~ get_name);

      // atomic sequence
      // uvm_create(req);

      for (size_t i=0; i!=1000; ++i) {
	import std.stdio;

	req.randomize();
	qemu_seq_item cloned = cast(qemu_seq_item) req.clone;
	uvm_send(cloned);
	// get_response(rsp);
      }
    
      // uvm_info("apb_rw", "Finishing sequence", UVM_MEDIUM);
    } // body

}

class qemu_sequencer: uvm_sequencer!qemu_seq_item
{
  mixin uvm_component_utils;
  
  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class apb_driver(string vpi_func):
  uvm_vpi_driver!(apb_rw!(32, 32), vpi_func)
{
  alias REQ=apb_rw!(32, 32);
  
  mixin uvm_component_utils;
  
  @UVM_BUILD {
    uvm_analysis_imp!(write) apb_analysis;
    // uvm_analysis_port!qemu_seq_item qemu_port;
  }

  this(string name, uvm_component parent) {
    super(name,parent);
  }
  
  override void run_phase(uvm_phase phase) {
    uvm_info ("INFO" , "Called my_driver::run_phase", UVM_DEBUG);
    super.run_phase(phase);
    get_and_drive(phase);
  }
	    
  void get_and_drive(uvm_phase phase) {
    while(true) {
      seq_item_port.get_next_item(req);
      drive_vpi_port.put(req);
      item_done_event.wait();
      seq_item_port.item_done();
    }
  }

  void write(apb_rw!(32, 32) item) {
    if (req.kind == kind_e.READ)
      req.data = item.data;
    // uvm_info("APB MONITOR", format("\n%s", item.sprint()), UVM_DEBUG);
  }
  
}

class qemu_driver(string vpi_func):
  uvm_vpi_driver!(apb_rw, vpi_func)
{
  alias REQ=apb_rw;
  
  mixin uvm_component_utils;
  
  REQ tr;

  this(string name, uvm_component parent) {
    super(name,parent);
  }
  
  override void run_phase(uvm_phase phase) {
    uvm_info ("INFO" , "Called my_driver::run_phase", UVM_DEBUG);
    super.run_phase(phase);
    get_and_drive(phase);
  }
	    
  void get_and_drive(uvm_phase phase) {
    while(true) {
      seq_item_port.get_next_item(req);
      drive_vpi_port.put(req);
      item_done_event.wait();
      seq_item_port.item_done();
    }
  }
}

class apb_agent(string VPI): uvm_agent
{
  mixin uvm_component_utils;

  @UVM_BUILD {
    apb_driver!(VPI)     driver;
    apb_sequencer       sequencer;
    apb_snooper!(VPI)    monitor;
  }

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  override void connect_phase(uvm_phase phase) {
    super.connect_phase(phase);
    if (get_is_active() == UVM_ACTIVE) {
      driver.seq_item_port.connect(sequencer.seq_item_export);
    }
  }
}

class qemu_env: uvm_env
{
  mixin uvm_component_utils;
  @UVM_BUILD {
    qemu_agent serial_agent;
    apb_agent!("apb") parallel_agent;
    apb_monitor u_apb_monitor;
  }

  this(string name, uvm_component parent) {
    super(name, parent);
  }
  // task
  override void connect_phase(uvm_phase phase) {
    super.connect_phase(phase);
    parallel_agent.sequencer.qemu_get_port.connect( serial_agent.sequencer.seq_item_export);
    parallel_agent.monitor.rsp_port.connect(u_apb_monitor.apb_analysis);
    parallel_agent.monitor.rsp_port.connect(parallel_agent.driver.apb_analysis);
  }
}

class qemu_agent: uvm_agent
{
  @UVM_BUILD {
    qemu_sequencer sequencer;
  }

  mixin uvm_component_utils;
   
  this(string name, uvm_component parent = null) {
    super(name, parent);
  }

  //override void connect_phase(uvm_phase phase) {
  //  driver.seq_item_port.connect(sequencer.seq_item_export);
//}
}

class apb_snooper(string vpi_func): uvm_vpi_monitor!(apb_rw!(32, 32), vpi_func)
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent = null) {
    super(name, parent);
  }
}


class apb_sequencer: uvm_sequencer!(apb_rw!(32, 32))
{
  mixin uvm_component_utils;
  @UVM_BUILD  {
    uvm_seq_item_pull_port!qemu_seq_item  qemu_get_port;
  }

  this(string name, uvm_component parent=null) {
    super(name, parent);
  }
}

class linux_fifo_test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD {
    qemu_env env;
  }

  override void run_phase(uvm_phase  phase) {
    apb_rw!(32, 32) item;
    // apb_seq!(32, 32) confiq_seq;
    apb_fifo_seq!(32, 32) qemu_seq;
    phase.raise_objection(this, "apb_test");
    File req_fifo = File("./qemu_apb_req.fifo", "r");
    File rsp_fifo = File("./qemu_apb_rsp.fifo", "w+");
    bool flag = true;
    while (flag) {
      qemu_seq = apb_fifo_seq!(32, 32).type_id.create("apb_seq");
      // qemu_seq.randomize();
      
      flag = qemu_seq.get_req_from_fifo(req_fifo);
      qemu_seq.sequencer = env.parallel_agent.sequencer;
      
      // qemu_seq.randomize();
      qemu_seq.start(env.parallel_agent.sequencer);
      
      uvm_info("QEMU SEQ", format("\n%s", qemu_seq.sprint()), UVM_DEBUG);
      uvm_info("QEMU SEQ", format("%s", qemu_seq._data), UVM_DEBUG);
    
      qemu_seq.put_rsp_to_fifo(rsp_fifo);
    }
    phase.drop_objection(this, "apb_test");
  }
}

class qemu_socket_test: uvm_test
{
  mixin uvm_component_utils;

  this(string name, uvm_component parent) {
    super(name, parent);
  }

  @UVM_BUILD {
    qemu_env env;
  }

  Socket _socket;

  override void build_phase(uvm_phase phase) {
    _socket = new Socket(AddressFamily.INET,
			 SocketType.STREAM);
    uvm_info("SOCKET", "Socket constructed", UVM_DEBUG);
  }

  override void connect_phase(uvm_phase phase) {
    uvm_info("SOCKET", "Waiting on socket at port 4201", UVM_DEBUG);
    _socket.connect(new InternetAddress("localhost", 4201));
    uvm_info("SOCKET", "Connected to socket at port 4201", UVM_DEBUG);
  }

  override void final_phase(uvm_phase phase) {
    uvm_info("SOCKET", "Shutting down socket at port 4201", UVM_DEBUG);
    _socket.shutdown(SocketShutdown.BOTH);
    _socket.close();
  }
  
  override void run_phase(uvm_phase  phase) {
    apb_rw!(32, 32) item;
    // apb_seq!(32, 32) confiq_seq;
    apb_socket_seq!(32, 32) qemu_seq;
    phase.raise_objection(this, "apb_test");
    bool flag = true;
    while (flag) {
      qemu_seq = apb_socket_seq!(32, 32).type_id.create("apb_seq");
      // qemu_seq.randomize();
      
      flag = qemu_seq.get_req_from_socket(_socket);
      qemu_seq.sequencer = env.parallel_agent.sequencer;
      
      // qemu_seq.randomize();
      qemu_seq.start(env.parallel_agent.sequencer);
      
      uvm_info("QEMU SEQ", format("\n%s", qemu_seq.sprint()), UVM_DEBUG);
      uvm_info("QEMU SEQ", format("%s", qemu_seq._data), UVM_DEBUG);
    
      qemu_seq.put_rsp_to_socket(_socket);
    }
    phase.drop_objection(this, "apb_test");
  }
}

void initializeESDL() {
  Vpi.initialize();

  auto test = new uvm_tb;
  test.multicore(0, 4);
  test.elaborate("test");
  test.set_seed(1);
  test.setVpiMode();

  test.start_bg();
}

alias funcType = void function();
shared extern(C) funcType[2] vlog_startup_routines = [&initializeESDL, null];
