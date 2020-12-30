pkt_len=12;
endian=0x0f;
op = 1;
data_len = 0;
version =1;
id = 0;
address = 0x20;
request = [endian,pkt_len,version,id,op,0,data_len,address].pack("CLSLCLLQ")
puts request