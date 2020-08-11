---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         PSEC4_dataBuffer.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  a process to store data from the PSEC4 into ram
--
--------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.dataRam;



entity dataBuffer is 
	port(	

		PSEC4_in : in	PSEC4_in_type;		
		channel :  OUT  natural range 0 to M-1;
		Token :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0);	
		blockSelect : out STD_LOGIC_VECTOR(2 DOWNTO 0);	
		readClock: out std_logic;	
		clock					:	in		std_logic;   	--40MHz clock from jitter cleaner
		reset					:	in		std_logic;	
		start					:  in		std_logic;
		ramReadAddress		:	in		natural; 
		ramDataOut			:	out	std_logic_vector(15 downto 0);	--13 bit RAM-stored data	
		done					:	out	std_logic);	-- the psec data has been read out and stored in ram
		
		
end dataBuffer;

architecture vhdl of dataBuffer is



signal	readClockEnable: std_logic;
signal	writeEnable: std_logic;
signal	writeEnable_z: std_logic;
signal	writeAddress: natural;
signal	writeAddress_z: natural;
signal	writeData: std_logic_vector(15 downto 0);
signal	readData: std_logic_vector(15 downto 0);
signal	writeAddress_slv: std_logic_vector(13 downto 0);
signal	readAddress_slv: std_logic_vector(13 downto 0);
signal	blockSel: natural;




begin
		
		
		
readClock <= clock and readClockEnable;
writeData <= x"0" & PSEC4_in.data;
ramDataOut <= readData;




DATA_RAM_MAP: dataRam PORT map
	(
		clock			=> clock,
		data			=> writeData,
		rdaddress	=> readAddress_slv,
		wraddress	=> writeAddress_slv,
		wren			=>	writeEnable_z,
		q				=> readData
	);

	
	
readAddress_slv <= std_logic_vector(to_unsigned(ramReadAddress,14));	
writeAddress_slv <= std_logic_vector(to_unsigned(writeAddress_z,14));	
blockSelect <= std_logic_vector(to_unsigned(blockSel,3));	
	
			

	
	
		
WR_PROCESS:	process(clock)

type state_type is (
	IDLE,
	INSERT_TOKEN, 
	WAIT_TOKEN, 
	WRITE_RAM_BLOCK, 
	WRITE_DONE);
	
variable wrCount: natural;
variable state: state_type;
variable i: natural;		-- sample number

begin
	
	if (falling_edge(clock)) then
			
		if (reset = '1')  then			
				
			Token	<= "00";
			writeEnable	<= '0';
			blockSel  	<= 5; -- clears ASIC token
			done	 		<= '0';
			state			:= IDLE;
		
		else
			
			
			case state is
				
				
				when IDLE =>
					
					if (start = '1') then
						writeAddress <= 0;
						channel <= 1;
						readClockEnable <= '1';
						blockSel   	<= 1;
						state := INSERT_TOKEN ; 
					end if;
									
					
				when INSERT_TOKEN =>

					if (channel >= 4 and channel <= 6) then
						Token <= "10";
					else
						Token <= "01";
					end if;
					state := WAIT_TOKEN;
					
						
				when WAIT_TOKEN =>
						
					Token <= "00";
					wrCount	:= 0;
					writeEnable	<= '1';
					state := WRITE_RAM_BLOCK;
				
					
				when WRITE_RAM_BLOCK =>			-- write 64 bytes at a time

					wrCount := wrCount + 1;
					writeAddress <= writeAddress + 1;
					if (wrCount >= 64) then   
						writeEnable <= '0';
						blockSel <= blockSel + 1;
						if (blockSel > 4) then
							blockSel <= 1;
							channel <= channel + 1;
							if (channel > 6) then
								state := WRITE_DONE;
							end if;
						end if;	
						state	:= INSERT_TOKEN; 
					end if;				
					
					
				when WRITE_DONE =>

					readClockEnable <= '0';
					done <= '1';
						
					
					
			end case;

		end if;
		
	elsif rising_edge(clock) then	
			
		writeAddress_z	<= writeAddress;
		writeEnable_z <= writeEnable;		

	end if;
	
end process;
	
	
	

end vhdl;