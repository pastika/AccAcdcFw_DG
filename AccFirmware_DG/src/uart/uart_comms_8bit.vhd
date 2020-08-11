---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE 
-- FILE:         uart_comms_8bit.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  uart comms module-
--                serializer /deserializer 
--
---------------------------------------------------------------------------------

LIBRARY ieee;
USE ieee.std_logic_1164.all; 
LIBRARY work;
use work.defs.all;
use work.components.uart;
use work.components.pulseSync;



ENTITY uart_comms_8bit IS 
	PORT
	(
		reset 				:  IN  STD_LOGIC;
		clock 				:  IN  clock_type;
		txIn 					:  IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		txIn_valid 			:  IN  STD_LOGIC;
		txOut 				:  OUT STD_LOGIC;
		rxIn 					:  IN  STD_LOGIC;
		rxOut 				:  OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		rxOut_valid			:  OUT STD_LOGIC;
		rxWordAlignReset  :  in STD_LOGIC;
		rxError				:  OUT STD_LOGIC		-- can be used to request a retransmission
		
	);
END uart_comms_8bit;


ARCHITECTURE vhdl OF uart_comms_8bit IS 



signal rxHighByte					:  std_logic_vector(7 downto 0);
signal rxByte						:	std_logic_vector(7 downto 0);
signal rxByte_valid				:	std_logic;
signal txByte						: 	std_logic_vector(7 downto 0);
signal txByte_valid				: 	std_logic;
signal txAck	:  std_logic;		-- data acknowledge from the UART
signal txReady			:  std_logic;
signal txIn_valid_z    		   : std_logic;
signal rxOut_valid_z   		   : std_logic;


TYPE txState_TYPE is (SEND_DATA, DATA_ACK);
signal txState		: txState_TYPE;



BEGIN 


--clocking notes:
-- processing is done with uart clock but I/Os are on the system clock



-- Data
--
-- tx input is 32 bit
-- rx output is 16 bit




-----------------------------
-- SERIALIZER / DESERIALIZER
-----------------------------
uart0 : uart
	GENERIC map 
	(	dataLen => 8, clockDivRatio	=> 16)
	PORT map
	(
		clock => clock.uart,
		reset => reset,	
		txData => txByte,
		txData_valid => txByte_valid,
		txData_ack	=> txAck,
		txReady	=> txReady,
		txOut => txOut,	
		rxData => rxByte,
		rxData_valid => rxByte_valid,
		rxError => rxError,
		rxIn => rxIn
	);

  
  
-----------------------------
-- TX STATE MACHINE
-----------------------------

-- Adds frame header info to valid input data and sends bytes to uart

-- synchronize
TX_SYNC: pulseSync port map (clock.sys, clock.uart, txIn_valid, txIn_valid_z);

process(clock.uart)
variable bytesDone: natural;
variable done: boolean;
variable txFrame : std_logic_vector(47 downto 0); -- 16 bit header + 32 bit data
begin
	if (rising_edge(clock.uart)) then
			
		 
      if (reset = '1') then
			
         txState <= SEND_DATA;
			txByte_valid <= '0';
			done := true;			
			
         
      else 
			

			case txState is			
            
            
            when SEND_DATA =>
				
					if (txReady = '1') then
						
						if (done and txIn_valid_z = '1') then 
							txFrame := STARTWORD_8a & STARTWORD_8b & txIn;
							done := false; 
							bytesDone := 0;
						end if;
						
						if (not done) then
							txByte <= txFrame(47 downto 40);	-- send msb first
							txByte_valid <= '1';
							txFrame := txFrame(39 downto 0) & X"00"; -- shift next byte into place
							bytesDone := bytesDone + 1;
							if (bytesDone >= 6) then done := true; end if;
							txState <= DATA_ACK;
						end if;
					
					end if;
					

				
				when DATA_ACK =>
				
					txByte_valid <= '0';
					if (txAck = '1') then
						txState <= SEND_DATA;
					end if;
            
            
			end case;
		end if;
	end if;
end process;



		
		

-----------------------------
-- RX WORD GENERATOR
-----------------------------
-- takes in bytes and turns them into 16 bit words

-- synchronize
DEC_VALID_OUT_SYNC: pulseSync port map (clock.uart, clock.sys, rxOut_valid_z, rxOut_valid);


process(clock.uart)
   variable getLowerByte : boolean;
   variable v:  std_logic;	-- 'valid' flag
begin
	if (rising_edge(clock.uart)) then	
     
      if (reset = '1' or rxWordAlignReset = '1') then
			
			rxOut_valid_z	<= '0';
         getLowerByte := false;
		
      else
			
         v := '0';
         if (rxByte_valid = '1') then      -- valid data received from uart			
				if (getLowerByte) then                     
					rxOut <= rxHighByte & rxByte;
					v := '1';
				else                    
					rxHighByte <= rxByte;
				end if;
				getLowerByte := not getLowerByte;                     
			end if;

			rxOut_valid_z	<= v;	 	 
         
				
            
      end if;
	end if;
end process;
	
		



END vhdl;









