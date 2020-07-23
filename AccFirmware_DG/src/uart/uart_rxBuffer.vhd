---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         uart_rxBuffer.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  counts 16 bit words in and stores them into the ram buffer
--
---------------------------------------------------------------------------------

library IEEE; 
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.components.rx_data_ram;
use work.defs.all;


entity uart_rxBuffer is
	port(
		reset				: in	std_logic;	--buffer reset and/or global reset
		clock				: in	std_logic;	--system clock		 
      din				: in	std_logic_vector(transceiver_mem_width-1 downto 0);--input data 16 bits
		din_valid		: in	std_logic;		 
		packetStarted  : out std_logic;	--a new packet has been started or is finished
		packetReceived : out	std_logic;	--a complete data packet has been written to RAM
      read_enable		: in	std_logic; 	--enable reading from RAM block
		read_address	: in	std_logic_vector(transceiver_mem_depth-1 downto 0);--ram address
		dataLen			: out natural range 0 to 65535;
		dout				: out	std_logic_vector(transceiver_mem_width-1 downto 0)--ram data out
		);	
		
end uart_rxBuffer;

architecture vhdl of uart_rxBuffer is

constant packetLen : natural := 7998;

type state_type	is (WRITE_TO_RAM, DONE);
signal state		:  state_type;		
signal wrData		:	std_logic_vector(transceiver_mem_width-1 downto 0); 
signal rdData		:	std_logic_vector(transceiver_mem_width-1 downto 0); 
signal wrAddress_slv				:	std_logic_vector(transceiver_mem_depth-1 downto 0);
signal wrAddress  : natural;
signal wrEnable  : std_logic;


-- note 
-- it is easier to have this module on the system clock,
-- then there are no problems interfacing the status signals
-- 
-- 40MHz clock should be more than enough to cope with the incoming data rate
-- even at 40Mbaud, that equates to 4Mbyte/sec max = 2Mword/sec @16bits
-- which is 20 clock cycles to process each 16-bit word
------------ RAM can be written at 40Mwords/sec = 80Mbytes/sec

begin


wrAddress_slv <= std_logic_vector(to_unsigned(wrAddress,transceiver_mem_depth));


RX_RAM_BUFFER: process(clock)
variable wrCount: natural;

begin
	if (rising_edge(clock)) then
	
		if (reset = '1') then
		
         packetStarted <= '0';			
         packetReceived <= '0';
         wrEnable <= '0';
         wrCount := 0;
			state <= WRITE_TO_RAM;
	
		else
	
			case state is
				
            
            
				when WRITE_TO_RAM =>
            
					wrEnable <= din_valid;
               
               if (din_valid = '1') then 
                  packetStarted <= '1';					              
                  wrData <= din;
                  wrAddress <= wrCount;
                  wrCount := wrCount + 1;    -- = number of words written
                  if (wrCount >= packetLen or din = ENDWORD) then
                     state <= DONE; 
                  end if;
               end if;
                    
                    
                                             
				when DONE =>    -- stays in this state until a reset (either a global reset or buffer reset from data handler)
					
               dataLen <= wrCount;  -- the number of bytes received and stored
					wrEnable <= '0';
               packetReceived	<= '1';										

                            
               
			end case;			
		end if;
	end if;
end process;


		
rx_RAM_map	:	rx_data_ram
port map(
		clock		   => clock,
		data		   => wrData,
		rdaddress	=> read_Address,
		rden		   => read_Enable,
		wraddress	=> wrAddress_slv,
		wren		   => wrEnable,
		q		      => dout);
		
			
end vhdl;
