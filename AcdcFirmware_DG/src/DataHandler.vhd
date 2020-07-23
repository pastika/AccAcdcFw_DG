---------------------------------------------------------------------------------
-- Univ. of Chicago HEP / electronics design group
--    -- + KICP 2015 --
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         dataHandler.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  transmits the stored ram data from all psec chips over the uart
--					  plus other information
--
--					  processing is done on sysClk, uart I/Os are on uart clock
---------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.pulseSync;



entity dataHandler is
	port (
		reset						: 	in   	std_logic;
		sys_clock				: 	in		std_logic;        
		uart_clock				: 	in		std_logic;        
		info						:  in 	info_type;
      readRequest				:	in		std_logic;
      readDone					:	out	std_logic;
		selfTrigRateCount		:	in 	rate_count_array;
		
      -- rx buffer ram signals
      ramAddress           :  out   std_logic_vector(RAM_ADR_SIZE-1 downto 0);
      ramData              :  in    wordArray;
      
      -- uart tx signals
      txByte	            : 	out	std_logic_vector(7 downto 0);
		txByte_valid	 	   : 	out	std_logic;
      txByte_ack           : 	in 	std_logic; -- a pulse input which shows that the data was sent to the uart
      txReady              : 	in 	std_logic; -- uart tx is ready for valid data
      
      -- error
      timeoutError  			:	out	std_logic
);
end dataHandler;


architecture vhdl of dataHandler is



type state_type is (
   WAIT_FOR_REQUEST,
   GET_DATA,
   SEND_BYTES,
   DATA_ACK);
   
   
   


signal txReady_z: std_logic;
signal txByte_valid_z:  std_logic;
signal txByte_ack_z:  std_logic;
signal address: natural;
  
	
	
begin	
	

               
ramAddress <= std_logic_vector(to_unsigned(address,14));






-- synchronize valid output to uart clock
SYNC0: pulseSync port map (sys_clock, uart_clock, txByte_valid_z, txByte_valid);

-- synchronize data ack input to sys clock
SYNC1: pulseSync port map (uart_clock, sys_clock, txByte_ack, txByte_ack_z);


   
   
DATA_HANDLER: process(sys_clock)
variable state: state_type;
variable t: natural; -- timeout value 
variable i: natural range 0 to 1600;  -- index of the current data word
variable txWord: std_logic_vector(15 downto 0);
variable bytesDone: natural;

-- flags to show the progress of the transmission
variable SOF_done: boolean;				-- start of frame
variable channelsDone: natural range 0 to 7;
variable preambleDone: boolean;
variable psecDataDone: boolean;
variable trigDone: boolean;
variable frameDone: boolean;




begin
	if (rising_edge(sys_clock)) then
	
		-- sync
		txReady_z <= txReady;
		
	
	
		if (reset = '1') then
			
			state := WAIT_FOR_REQUEST;
			txByte_valid_z <= '0';
         
			
		else
		
         
         case state is
                 
         
				when WAIT_FOR_REQUEST => 
			             
					readDone <= '0';
					txByte_valid_z <= '0';
					if (readRequest = '1') then 
						i := 0;
						t := 0;
						address <= 0;
						timeoutError <= '0';
						SOF_done := false;
						channelsDone := 0;
						preambleDone := false;
						psecDataDone := false;
						trigDone := false;
						frameDone := false;
						state := GET_DATA;
					end if;
               
					
            when GET_DATA =>
						
						-- choose the correct data 
						if (not SOF_done) then		-- start of frame
							txWord := STARTWORD; 
							i := i + 1;
							if (i >= 2) then		-- send twice
								i := 0;
								SOF_done := true;
							end if;
                  
						
						elsif (channelsDone < 5) then
							
							if (not preambleDone) then		-- preamble
								txWord := x"F005";
								i := 0;
								preambleDone := true;
							
							elsif (not psecDataDone) then
								txWord := std_logic_vector(to_unsigned(i,16)); --ramReadData(ch);
								address <= address + 1;
								i := i + 1;
								if (i >= 1536) then			-- 256 words x 6 channels
									psecDataDone := true;
									i := 0;
								end if;
								
							else							-- postamble
								if (i < 2) then
									txWord := x"BA11";
									i := i + 1;									
								elsif (i < 15) then
									txWord := info(channelsDone, i - 2);
									i := i + 1;
								else
									txWord := PSEC_END_WORD;
									i := 0;
									channelsDone := channelsDone + 1;		-- finished the current channel
									preambleDone := false;
									psecDataDone := false;
								end if;
									
							end if;
							
						elsif (not trigDone) then		-- trigger
						
							txWord := selfTrigRateCount(i);
							i := i + 1;
							if (i = 30) then
								i := 0;
								trigDone := true;
							end if;
						
						else
						
							txWord := ENDWORD;
							i := i + 1;
							if (i >= 3) then
								frameDone := true;
							end if;						

                  end if;
						
						t := 40000000;  -- set timeout delay 1s for data acknowledge
                  bytesDone := 0;
						state := SEND_BYTES;
                              
                  
				when SEND_BYTES =>
					
					if (txReady_z = '1') then
						case bytesDone is		-- choose the upper or lower byte of the 16-bit word
							when 0 => txByte <= txWord(15 downto 8);	-- send msb first
							when others => txByte <= txWord(7 downto 0);
						end case;
						txByte_valid_z <= '1';
						state := DATA_ACK;
					end if;

                  
            when DATA_ACK =>
               txByte_valid_z <= '0';
               if (txByte_ack_z = '1') then  -- the new data was acked
                  bytesDone := bytesDone + 1;
						t := 0; -- clear timeout
                  if (bytesDone >= 2) then 		-- the 16-bit word has been sent
                     if (frameDone) then 
								readDone <= '1';
								state := WAIT_FOR_REQUEST;
							else
								state := GET_DATA;
							end if;
                  else
                     state := SEND_BYTES;
                  end if;
               end if;
               
 
               
         end case;
         
         
         
         
         -- timeout error
         
         if (t > 0) then
            t := t - 1;
            if (t = 0) then 
               timeoutError <= '1';   -- generate an output pulse to indicate the error
               state := WAIT_FOR_REQUEST; 
            end if;     
         else
            timeoutError <= '0';
         end if;
         
         
         
         
      end if;
      
   end if;
   
   
end process;
               
               
               
    
    
		
end vhdl;































