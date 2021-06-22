---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         uart_rxBuffer.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
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
      read_enable		: in	std_logic; 	--enable reading from RAM block
		read_address	: in	std_logic_vector(transceiver_mem_depth-1 downto 0);--ram address
		buffer_empty	: out std_logic;
		frame_received	: buffer std_logic;
		dataLen			: out natural range 0 to 65535;
		dout				: out	std_logic_vector(transceiver_mem_width-1 downto 0)--ram data out
		);	
		
end uart_rxBuffer;

architecture vhdl of uart_rxBuffer is

constant MaxLen : natural := 8192;

signal wrData		:	std_logic_vector(transceiver_mem_width-1 downto 0); 
signal rdData		:	std_logic_vector(transceiver_mem_width-1 downto 0); 
signal wrAddress_slv				:	std_logic_vector(transceiver_mem_depth-1 downto 0);
signal wrAddress  : natural;
signal wrEnable  : std_logic;


-- 40MHz clock should be more than enough to cope with the incoming data rate
-- even at 40Mbaud, that equates to 4Mbyte/sec max = 2Mword/sec @16bits
-- which is 20 clock cycles to process each 16-bit word
------------ RAM can be written at 40Mwords/sec = 80Mbytes/sec

begin


wrAddress_slv <= std_logic_vector(to_unsigned(wrAddress,transceiver_mem_depth));


RX_RAM_BUFFER: process(clock)
variable wrCount: natural;
variable t: natural;
variable eof: std_logic; 	-- end of frame
begin
	if (rising_edge(clock)) then
	
		if (reset = '1') then
		
         wrEnable <= '0';
         wrCount := 0;
			dataLen <= 0;
			eof := '0';
			buffer_empty <= '1';
			frame_received <= '0';
	
		else
	
         if (t < 10000) then t := t + 1; end if;
			 
         if (din_valid = '1' and wrCount < MaxLen and eof = '0') then 
					wrData <= din;
					wrAddress <= wrCount;
					wrCount := wrCount + 1;    -- = number of words written
					dataLen <= wrCount;  -- the number of bytes received and stored
					buffer_empty <= '0';
					if (wrCount = 7795) then eof := '1'; end if;
					t := 0;
					wrEnable <= '1';
			else
    				wrEnable <= '0';		 
         end if;
                    
			
			
			-- Timer to detect short frames
			--------------------------------
			-- If less than the maximum number of words is transmitted in a frame from the ACDC,
			-- there has to be a way to detect end of frame.
			--
			-- This is done by checking the elapsed time since a data word was last received.
			-- If this delay exceeds a certain value, end of frame is flagged.
			--
			-- The ACDC will always transmit bytes with virtually no gaps so this method of
			-- detection is valid, and allows variable length frames to be sent.
			
			
			-- signal end of frame after 10us of no data being received			
			-- but at lease one word should have been received before starting the timer
			if (wrCount >= 1 and t > 400) then eof := '1'; end if;		
						  
						  
			frame_received <= eof;
                    
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
