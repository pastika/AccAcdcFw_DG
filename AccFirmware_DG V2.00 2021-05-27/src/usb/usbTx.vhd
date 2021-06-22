---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      
-- FILE:         usbTx.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  writes 16 bit words to the usb chip 
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;
use work.LibDG.pulseSync;




entity usbTx_driver is
   port ( 	
			clock   		: in		clock_type;
			reset	      : in  	std_logic;	   --reset signal to usb block
			txLockReq  	: in		std_logic;  -- request to lock the bus in tx mode, preventing any interruptions from usb read
			txLockAck  	: out		std_logic;  
			txLockAvailable  	: in		std_logic; --the bus can be locked in tx mode when high. Once locked will stay locked regardless of this signal
			din	   	: in		std_logic_vector (15 downto 0);  
			din_valid  	: in		std_logic;  -- only a single pulse is needed
			txReady     : out    std_logic;  -- indicates that valid data may be applied to the input
         txAck    	: out		std_logic;  -- a single pulse to show the data was transmitted
         busReadEnable : in     std_logic; --input from rx module to control the bus tristate
         bufferReady : in  	std_logic;		--the tx buffer on the chip is ready to accept data 
         PKTEND      : out 	std_logic;		--usb packet end flag
         SLWR        : out 	std_logic;		--usb slave interface write signal
         txBusy  		: out 	std_logic;     --usb write-busy indicator (not a PHY pin)
			dout 			: out    std_logic_vector (15 downto 0);  --usb data bus to PHY
         timeoutError: out    std_logic);
	end usbTx_driver;

	
	
architecture vhdl of usbTx_driver is

--  _z suffix indicates usb clocked signal	
	signal 	reset_z:	std_logic;	-- reset signal synchronized with IFCLK
	signal 	txLockReq_z:	std_logic;	
	signal 	din_valid_z:	std_logic;	
	signal 	txLockAck_z:	std_logic;	
	signal 	txReady_z:	std_logic;	
	signal 	txAck_z:	std_logic;	
   signal   timeoutError_z: std_logic;
	signal   busy: std_logic;
	signal   busWriteEnable: std_logic_vector(15 downto 0);
   signal	bufferReady_z: std_logic;
   
   
   type  state_type is (
      BUS_REQUEST, 
      BUFFER_WAIT,
      DATA_WAIT,
      WR_LOW,
	  WR_HIGH,
	  PKTEND_LOW,
	  PKTEND_HIGH);
      
   signal   state:  state_type;
   
   
--note
--inputs on system clock:
-- reset
-- txLockReq
-- din_valid

--outputs on system clock:
-- txLockAck
-- txReady
-- txAck




-- Timings from datasheet
-------------------------
-- Aynchronous write: (p.51)
-- SLWR low 50ns minimum = 3 clocks @ 48MHz
-- SLWR high 70ns minimum = 4 clocks @ 48MHz
-- SLWR to FIFO data setup time 10ns 
--
-- Aynchronous packet end: (p.54)
-- PKTEND low 50ns minimum = 3 clocks @ 48MHz
-- PKTEND high 50ns minimum = 3 clocks @ 48MHz
--
-- Write: safer to make it low 4/ high 5 clocks to account for pcb delay, fpga delay
-- Pkt end: safer to make it low 4/ high 4 clocks to account for pcb delay, fpga delay

-- use synchronous write: 1 clock SLWR low, 1 clock SLWR high; 
-- use asynchronous packet end: 4 clocks low, 4 clocks high



	-- timing constants (number of clock cycles)
	constant    timing_SLWR_LOW: natural:= 4;
	constant    timing_SLWR_HIGH: natural:= 5;
	constant    timing_PKTEND_LOW: natural:= 4; 
	constant    timing_PKTEND_HIGH: natural:= 4; 
	


	
begin



txBusy <= busy;

-- transfer inputs to usb clock
SYNC0: pulseSync port map (clock.sys, clock.usb, din_valid, din_valid_z);

-- transfer output to sys clock
SYNC1: pulseSync port map (clock.usb, clock.sys, txAck_z, txAck);


-- before data can be applied to the module, txLockReq must be raised 
-- when txLockAck goes high, data and valid signals can be applied

--
-- txAck goes high for one pulse only indicating data was sent


---------------------------------------------------------------------------------
--USB write to PC
---------------------------------------------------------------------------------
proc_usb_write : process(clock.usb)
variable t: natural;
variable cyc: natural;
	begin
		if (rising_edge(clock.usb)) then
		
			-- sync
			reset_z <= reset;
			txLockReq_z <= txLockReq;
         bufferReady_z <= bufferReady;
         
			
			if (reset_z = '1') then	-- active high
			
				state			<= BUS_REQUEST;
				busy			<= '0';
				SLWR 			<=	'1';
				PKTEND 		<=	'1';
            txAck_z     <= '0';
				timeoutError_z <= '0';
            txReady_z   <= '0';      
            t := 0;
            
            
			else

            
				case state is
             
            
               when BUS_REQUEST =>     -- wait for a request to use the bus for tx               
                  if (txLockReq_z = '1' and txLockAvailable = '1') then  -- wait for bus available
                     busy <= '1'; -- bus is locked for writing - usb read can't operate while tx busy is high
                     state <= BUFFER_WAIT; 
                  end if; 

                  
               when BUFFER_WAIT => -- wait until chip is ready to accept data
                  txAck_z <= '0';
                  if (bufferReady_z = '1') then
                     txReady_z <= '1';      -- signal to the external module to start sending data
                     state <= DATA_WAIT;
                  end if;                    
                  

               when DATA_WAIT => 
                  if (din_valid_z = '1') then 
                     dout <= din; 
                     SLWR <= '0'; 
							cyc := 0;
                     txReady_z <= '0';      
                     state <= WR_LOW; 
                  elsif (txLockReq_z = '0') then   -- this signals end of input data. Send packet end and then release the bus
                     PKTEND <= '0'; -- send packet end signal
                     cyc := 0;
							state <= PKTEND_LOW; 
                  end if;                    
                  
				  
				  
				  
                 -- write cycle 
				when WR_LOW =>     -- keep SLWR low for the specified number of cycles
               cyc := cyc + 1;
					if (cyc >= timing_SLWR_LOW) then 
						cyc := 0;
						SLWR <= '1';
						txAck_z <= '1';   -- single pulse on this indicates the data was transmitted. Driving module should detect rising edge on this
						state <= WR_HIGH;
					end if;                             
							
				when WR_HIGH =>     -- keep SLWR high for the specified number of cycles
					txAck_z <= '0'; 
               cyc := cyc + 1;
					if (cyc >= timing_SLWR_HIGH) then
						state <= BUFFER_WAIT;
					end if;
               
			   
			   
			   -- packet end
				when PKTEND_LOW =>     -- keep PKTEND low for the specified number of cycles
					cyc := cyc + 1;
					if (cyc >= timing_PKTEND_LOW) then 
						cyc := 0;
						PKTEND <= '1';
						state <= PKTEND_HIGH;
					end if;                            
							
				when PKTEND_HIGH =>     -- keep PKTEND high for the specified number of cycles
					cyc := cyc + 1;
					if (cyc >= timing_PKTEND_HIGH) then
						busy <= '0';      -- this in turn lowers the txLockAck signal
						state <= BUS_REQUEST;
					end if;
               			   
                  
               
               
            end case;
            
             
            
            
       -- timeout 
            
            if (t > 0) then   
               t := t - 1;
               if (t = 0) then 
                  timeoutError_z <= '1'; 
                  txAck_z <= '0';
                  txReady_z <= '0'; 
                  SLWR <= '1';
                  PKTEND <= '1';
                  busy <= '0';
                  state <= BUS_REQUEST;
               end if;
            else
               timeoutError_z <= '0';                 
            end if;

            
            
            
         end if;
      end if;
   end process;
   
 




------------------------------------
--	SYNC OUTPUTS TO SYS CLOCK
------------------------------------
SYNC_OUTPUTS: process(clock.sys)
begin
   if (rising_edge(clock.sys)) then
      txLockAck <= busy;
      txReady <= txReady_z;
   end if;
end process;
   
TIMEOUT_SYNC: pulseSync port map (clock.usb, clock.sys, timeoutError_z, timeoutError);


   
   
   

end vhdl;



