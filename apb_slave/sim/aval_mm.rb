#!/usr/bin/env ruby

class Aval_mm

  WRITE=0;
  READ=1;
  IDLE=2;
  DONE=3;
  WRITE_RSP=4;
  READ_RSP=5;
  IDLE_RSP=6;
  DONE_RSP=7;

  def initialize
    @fifo = File.open("qemu_apb_req.fifo", "w+")
    print "file opened successfully:\n"
    @id = 0
    @version = 1;
  end

  def write(address, *wdata)
    pkt_len=16;
    endian=0x0f;
    #op = 1;
    op=WRITE;
    data_len = 4;
    request = ([endian, pkt_len, @version, @id, op, 0, data_len, address] + wdata).pack("CLSLCLLQL")
    puts "Write: #{request.inspect}"
    print "Write Request => "
    p [endian, pkt_len, @version, @id, op, 0, data_len, address] + wdata
    @fifo.print(request)
    @fifo.flush()
    @id += 1
    # resp = @fifo.read()
    # response = resp.unpack("CLSLCLQ")
  end

  def read(address)
    pkt_len=12;
    endian=0x0f;
    op = READ;
    data_len = 0;
    request = [endian, pkt_len, @version, @id, op, 0, data_len, address].pack("CLSLCLLQ")
    puts "Read: #{request.inspect}"
    print"Read Request =>  "
    p [endian, pkt_len, @version, @id, op, 0, data_len, address]
    @fifo.print(request)
    @fifo.flush()
    @id += 1
  end

  def ctrl_command()
    pkt_len = 0;
    endian=0x0f;
    op = DONE;
    request = [endian, pkt_len, @version, @id, op].pack("CLSLC")
    print "Term Request =>  "
    p [endian, pkt_len, @version, @id, op]
    @fifo.print(request)
    @fifo.flush()
    @id += 1
  end

end

mm = Aval_mm.new
mm.read(0x2C);
# mm.read(0x20);
# sleep(2)
# mm.write(0x20, 0x55);
# sleep(2)
# # mm.write(0x20, 0x55);
# mm.read(0x20);
# sleep(2)
# mm.write(0x24, 0xaa);
# sleep(2)
# mm.read(0x24);
# sleep(2)
# mm.write(0x28, 0xcc);
# sleep(2)
# mm.read(0x28);
# sleep(2)
# for i in 0..1 do
  # mm.write(0x2C, 0x50);
  # mm.read(0x2C);
# end
# mm.read(0x28);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
# mm.read(0x20);
# sleep(2)
mm.ctrl_command();

