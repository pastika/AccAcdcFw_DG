---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      
-- FILE:         usbRx.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  receives 32-bit words from the usb port by joining two successive 16 bit words
--
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;
use work.components.pulseSync;


-- Timings from datasheet
-------------------------
-- Aynchronous read:
-- SLRD low 50ns minimum = 3 clocks @ 48MHz
-- SLRD high 50ns minimum = 3 clocks @ 48MHz
-- propagation delay SLRD low to FIFO data out 15ns 
--
-- safer to make it 4 clocks to account for pcb delay, fpga delay



entity usbRx_driver is
   port ( 
		clock				: in		clock_type;
		reset		      : in  	std_logic;	   --reset signal to usb block
		din  		      : in     std_logic_vector (15 downto 0);  --usb data from PHY
      busReadEnable 	: out   	std_logic;     --when high disables drive to usb bus thus enabling reading
      enable       	: in    	std_logic;     --allow reading of usb data
      dataAvailable  : in    	std_logic;     --usb data received flag
      SLOE         	: out   	std_logic;    	--usb slave interface bus output enable, active low
      SLRD     	   : out   	std_logic;		--usb  slave interface bus read, active low
      FIFOADR  	   : out   	std_logic_vector (1 downto 0); -- usb endpoint fifo select, essentially selects the tx fifo or rx fifo
      busy 		      : out   	std_logic;		--usb read-busy indicator (not a PHY pin)
      dout           : out   	std_logic_vector(31 downto 0);
		dout_valid     : out		std_logic;						
      timeoutError   : out    std_logic);
      end usbRx_driver;

	
	
architecture vhdl of usbRx_driver is

	
	signal 	reset_z:	std_logic;	-- reset signal synchronized with IFCLK
	signal 	timeoutError_z:	std_logic;	
   signal   usb_dout           : std_logic_vector(31 downto 0); -- 32 bit word constructed from two received 16 bit words
   signal   usb_dout_valid     : std_logic;	-- goes high for one (usb clock) pulse to indicate valid data	
	signal	dataAvailable_z : std_logic;
	
	
	constant    timeoutValue: natural:= 48000000; --  = 1 sec @ 48MHz clock
	
	
	
	-- timing constants (number of clock cycles)
	constant    timing_SLRD_LOW: natural:= 4; 
	constant    timing_SLRD_HIGH: natural:= 4; -- as well as meeting datasheet timing, this also gives a couple of clocks to allow dataAvailable_z to go low
	constant 	holdoffTime: natural:= 0;		-- number of clocks to wait between instructions. Gives time to process instruction
	
   
   
begin



--------------------------------------------------------------------------------
---------------------------------------------------------------------------------
--USB read from PC
---------------------------------------------------------------------------------
proc_usb_read : process(clock.usb)
variable isLower: boolean; -- flag to say this is the lower 16 bits of the command word (bits 15 to 0)
variable holdoff: natural; -- a timer to ensure a minimum number of clock cycles between successive received 32-bit instruction words (if needed)
variable t: natural; -- a timeout timer
type state_type is (RD_WAIT, RD_LOW, RD_HIGH);
variable state: state_type;
variable error: boolean;   --error flag
variable cyc: natural;
	begin
		if rising_edge(clock.usb) then
			
         -- synchronize the reset signal, as it comes from the system clock
         reset_z <= reset;
         dataAvailable_z <= dataAvailable;
         
         
         if (reset_z = '1') then
               
            timeoutError_z <= '0'; 
				SLRD 			   <= '1'; 
				SLOE 			   <= '1';
				FIFOADR 		   <= "10"; --default is tx fifo
				busReadEnable  <= '0';
				isLower 		   := true; -- waiting for the lower 16 bits of command word
				busy 		      <= '0';
				usb_dout_valid <= '0';
				holdoff     := 0;
				t := 0;
				state       := RD_WAIT;
                        
			
         else
				
            


            if (holdoff > 0) then holdoff := holdoff - 1; end if;
            
            
            
            
				case	state is	
					    
						
               when RD_WAIT =>	-- check if read data available and bus is available for reading
                  usb_dout_valid <= '0';
                  
                  if (dataAvailable_z = '1' and enable = '1' and holdoff = 0) then	-- flagA = rx data available
							busy <= '1';   -- flag to the tx driver that the bus is not available
							cyc := 0;
							busReadEnable <= '1';   -- disable acc bus drive to allow reading from usb chip; 
							FIFOADR <= "00"; -- select the rx data fifo  
							SLOE <= '0'; 
							SLRD <= '0';	
							state := RD_LOW;
						elsif (isLower) then -- only lower busy if waiting for lower bits, this keeps busy high while waiting for upper part of command word
                     busy <= '0'; 
                  end if;
               

               when RD_LOW =>	-- SLRD = low
						cyc := cyc + 1;
						if (cyc >= timing_SLRD_LOW) then		-- keep SLRD low for a specified number of cycles before accessing the data
							if (isLower) then
								usb_dout(15 downto 0) <= din;
								t := timeoutValue;     -- set timer to read upper command bits. So if it gets half a command then it will reset to waiting for lower bits again
							else -- full 32 bits were received
								usb_dout(31 downto 16) <= din;
                        usb_dout_valid <= '1'; 
                        t := 0;  -- clear timeout timer
                        holdoff := holdoffTime;		-- allows time for the instruction to be processed before receiving the next one
							end if;
							isLower := not isLower;
							SLRD <= '1'; 					               
							SLOE <= '1';	
							cyc := 0;
							state := RD_HIGH;
						end if;
               
	
					when RD_HIGH => 	-- SLRD = high
						cyc := cyc + 1;
						if (cyc >= timing_SLRD_HIGH) then 		-- keep SLRD high for a specified number of cycles before returning to start
							FIFOADR 		   <= "10"; -- select the tx fifo while not reading to allow tx operations to go ahead
							busReadEnable 	<= '0'; -- allow tx to drive the bus                                  
							state := RD_WAIT;
						end if;
            
			
            end case;
            

            
         -- error handling
            
            if (t > 0) then   -- timeout timer active
               t := t - 1;
               if (t = 0) then 	-- expired
					timeoutError_z <= '1';
					isLower := true;              
					state := RD_HIGH;		-- reset the FIFOADR and busReadEnable signals
				end if;
            else 
               timeoutError_z <= '0'; 
            end if;




            
         end if;
      end if;
   end process;
 
 
 
 
 
 
 
------------------------------------
--	OUTPUT SYNC TO SYS CLOCK
------------------------------------
-- transfer the valid signal to the system clock
-- (data should not need syncing as it shouldn't be changing)
VALID_SYNC: pulseSync port map (clock.usb, clock.sys, usb_dout_valid, dout_valid);
dout <= usb_dout;

   
TIMEOUT_SYNC: pulseSync port map (clock.usb, clock.sys, timeoutError_z, timeoutError);
   

  
 
 
 
 
end vhdl;











