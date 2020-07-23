---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ACC
-- FILE:         dataHandler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  a state machine to get the data from the rx buffers and also local 
-- 				  data sent across the usb link in a timely and orderly fashion
--			        it is initiated automatically when the rx buffers become full
--				     but can be invoked manually aswell
--	       	     readMode determines what data is sent
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.defs.all;



entity dataHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
		readMode             : in std_logic_vector(2 downto 0);      
      
      -- rx buffer ram signals
      ramReadEnable        : 	out 	std_logic_vector(7 downto 0);
      ramAddress           :  out   std_logic_vector(transceiver_mem_depth-1 downto 0);
      ramData              :  in    rx_ram_data_type;
      rxDataLen				:  in  	naturalArray_16bit;
		bufferReadoutDone    :  out   std_logic_vector(7 downto 0);
      
      -- usb tx signals
      dout 		            : 	out	std_logic_vector(15 downto 0);
		dout_valid			   : 	out	std_logic;
      txAck                : 	in 	std_logic; -- a pulse input which shows that the data was sent to the usb chip
      txReady              : 	in 	std_logic; -- usb tx is ready for valid data
      txLockReq            : 	out	std_logic;
      txLockAck            : 	in  	std_logic;
      
      -- local info
      localInfo_readRequest: in std_logic;      
		localInfo				: in frameData_type;
      linkStatusOk         : in std_logic_vector(7 downto 0);    
      trigInfo             : in std_logic_vector(2 downto 0);    
      rxPacketStarted      : in std_logic_vector(7 downto 0);    
      rxPacketReceived     : in std_logic_vector(7 downto 0);

      -- error
      timeoutError  			:	out	std_logic);
end dataHandler;


architecture vhdl of dataHandler is



type state_type is (
   CHECK_IF_SEND_DATA,
   BUS_REQUEST,
   DATA_SEND,
   DATA_ACK,
   DONE);
   
   


-- local data frame
constant localData_frameLen: natural := 32;


-- ram data frame
constant rxData_headerLen: natural := 7;
constant rxData_frameLen: natural := 8001;
   
   
   


signal localData:  frameData_type;
signal rxData_header:  frameData_type;
signal rxData_frameEnd:  frameData_type;
signal address: natural;
signal txAck_z: std_logic;
   
	
	begin	
	

               
ramAddress <= std_logic_vector(to_unsigned(address,15));



-- notes
--
-- The handshaking between this module and usb tx is quite important because
-- usb tx internally uses a different clock which is unsynchronized, 
-- even the I/O are on the system clock. 
--
-- This means that you don't know exactly how many clock cycles the tx acknowledgement
-- will take to come back, or which clock cycle it will begin.
--
-- The important thing is that you don't put valid data in while the tx ack from 
-- the previous data is still there, thus giving a false ack.
--
-- It was decided to detect a rising edge on tx ack so that you definitely know it has gone low
-- previously. 







   
   
DATA_HANDLER: process(clock)
variable getRamData: boolean;
variable getLocalData: boolean;
variable ch: integer;
variable state: state_type;
variable t: natural; -- timeout value 
variable i: natural;  -- the index of the current data word within the frame = number of words done
variable frameLen: natural;
variable rdMode: natural; -- an integer version of the 3 bit slv 'readMode'
variable holdoff: natural; -- a delay between successive frames to give chance for rxPacketReceived to go low

begin
	if (rising_edge(clock)) then
	
		if (reset = '1') then
			
         bufferReadoutDone <= x"00";
			state := CHECK_IF_SEND_DATA;
         ramReadEnable <= X"FF"; 
         timeoutError <= '0';
         dout_valid <= '0';
         txLockReq <= '0';
			holdoff := 0;
         t := 0;
         
			
		else
		
			
         -- tx data acknowledge - rising edge detect
         
         txAck_z <= txAck;
         
         
			if (holdoff > 0) then holdoff := holdoff -  1; end if;
         
         
         
         case state is
         
         
         
				when CHECK_IF_SEND_DATA => -- check for rx buffer full, or request to send local info
			             
               i := 0;
               t := 0;
               address <= 0;
               bufferReadoutDone <= x"00";
               timeoutError <= '0';
               
               getRamData := false;    -- flags used to indicate frame type required
               getLocalData := false;
               
               rdMode := to_integer(unsigned(readMode));
               
					if (rdMode >= 1 and rdMode <= 4) then
						ch := rdMode - 1;
						if (rxPacketReceived(ch) = '1' and holdoff = 0) then 
							frameLen :=  rxData_FrameLen;
							getRamData := true; 
						end if;
				
					elsif (rdMode = 5) then
						if (localInfo_readRequest = '1') then 
							frameLen := localData_frameLen;
							getLocalData := true; 
						end if;
					end if;
                             
					if (getLocalData or getRamData) then
						state := BUS_REQUEST;
					end if;
               
			   
            when BUS_REQUEST =>               
               txLockReq <= '1';  -- request locking the usb bus in tx mode
               if (txLockAck = '1') then state := DATA_SEND; end if;  -- usb bus acknowledge, bus is now locked for tx use
               
               

            when DATA_SEND =>
               -- choose the correct data depending on the frame type and index pos within the frame
               if (txReady = '1') then
                  if (getLocalData) then   
                     dout <= localData(i);
                  else
                     if (i < rxData_headerLen) then dout <= rxData_header(i); --header                    
                     elsif (address < rxDataLen(ch)) then -- ram data
								dout <= ramData(ch); --ram data                     
								address <= address + 1; -- increment address counter once the main data body is started
                     elsif (address = rxDataLen(ch)) then
								dout <= rxData_frameEnd(0);-- frame end delimiter
								address <= address + 1; 
                     else
								dout <= x"0000";  -- null data to pad out the frame
							end if;
                  end if;
                  dout_valid <= '1';   -- initiate the usb tx process
                  i := i + 1; -- increment the index   (= number of words done)            
                  t := 40000000;  -- set timeout delay 1s for data acknowledge
                  state := DATA_ACK;
               end if;
               
                  
                  
            when DATA_ACK =>
               dout_valid <= '0';
               if (txAck_z = '0' and txAck = '1') then  -- rising edge detect means the new data was acked
                  t := 0; -- clear timeout
                  if (i = frameLen) then
                     state := DONE;
                  else
                     state := DATA_SEND;
                  end if;
               end if;
               
 

 
            when DONE => 
               txLockReq <= '0';    -- this going low causes the packet end signal to be sent and gives chance for the read module to operate if necessary
               if (txLockAck = '0') then                
                  if (getRamData) then bufferReadoutDone(ch) <= '1'; end if; -- flag that the buffer was read. This is used to reset the corresponding buffer write process
                  holdoff := 5;
						state := CHECK_IF_SEND_DATA;
               end if;
               
               
               
         end case;
         
         
         
         
         -- timeout error
         
         if (t > 0) then
            t := t - 1;
            if (t = 0) then 
               timeoutError <= '1';   -- generate an output pulse to indicate the error
               state := DONE; 
            end if;     
         else
            timeoutError <= '0';
         end if;
         
         
         
         
      end if;
      
   end if;
   
   
end process;
               
               
               
    
    
    
               
--------------------------------------------
-- RX RAM DATA FRAME 
--------------------------------------------              

-- header
rxData_header(0) <= x"1234";
rxData_header(1) <= localInfo(0);
rxData_header(2) <= localInfo(1);
rxData_header(3) <= localInfo(2);
rxData_header(4) <= localInfo(3);
rxData_header(5) <= localInfo(4);
rxData_header(6) <= localInfo(5);

-- frame end
rxData_frameEnd(0) <= x"4321";


-- the main body of the frame comes from rx data ram




--------------------------------------------
-- LOCAL DATA FRAME
--------------------------------------------              
localData(0) <= x"1234";
localData(1) <= x"DEAD";
localData(2) <= linkStatusOk & linkStatusOk;
localData(3) <= localInfo(0);
localData(4) <= localInfo(1)(0) & trigInfo & x"0" & rxPacketStarted(3 downto 0) & rxPacketReceived(3 downto 0);
localData(5) <= localInfo(2);
localData(6) <= localInfo(3);
localData(7) <= localInfo(4);
localData(8) <= localInfo(5);
localData(9) <= localInfo(6);
localData(10) <= localInfo(7);
localData(11) <= x"BEEF";
localData(12) <= x"4321";
localData(13) <= x"0000";
localData(14) <= x"0000";
localData(15) <= x"0000";
localData(16) <= x"0000";
localData(17) <= x"0000";
localData(18) <= x"0000";
localData(19) <= x"0000";
localData(20) <= x"0000";
localData(21) <= x"0000";
localData(22) <= x"0000";
localData(23) <= x"0000";
localData(24) <= x"0000";
localData(25) <= x"0000";
localData(26) <= x"0000";
localData(27) <= x"0000";
localData(28) <= x"0000";
localData(29) <= x"0000";
localData(30) <= x"0000";
localData(31) <= x"0000";


               
               
               
               
               
			
end vhdl;































