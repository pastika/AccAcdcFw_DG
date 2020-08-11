---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         defs.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defs is


constant N	:	natural := 8; --number of front-end boards (either 4 or 8, depending on RJ45 port installation)



--RAM specifiers for uart receiver buffer
constant	transceiver_mem_depth	:	integer := 15; --ram address size
constant	transceiver_mem_width	:	integer := 16; --data size


--defs for the SERDES links
constant STARTWORD				: 	std_logic_vector := x"1234";
constant STARTWORD_8a			: 	std_logic_vector := x"B7";
constant STARTWORD_8b			: 	std_logic_vector := x"34";
constant ENDWORD					: 	std_logic_vector := x"4321";
constant ALIGN_WORD_16 			: 	std_logic_vector := x"FACE";
constant ALIGN_WORD_8 			:  std_logic_vector := x"CE";


--type definitions
type rx_ram_data_type is array(N-1 downto 0) of	std_logic_vector(transceiver_mem_width-1 downto 0);
type LVDS_inputArray_type is array(N-1 downto 0) of std_logic_vector(3 downto 0);
type LVDS_outputArray_type is array(N-1 downto 0) of std_logic_vector(2 downto 0);
type Array_8bit is array(N-1 downto 0) of std_logic_vector(7 downto 0);
type Array_16bit is array(N-1 downto 0) of std_logic_vector(15 downto 0);
type frameData_type is array(31 downto 0) of std_logic_vector(15 downto 0);
type naturalArray_16bit is array(N-1 downto 0) of natural range 0 to 65535;
	
	
	
-- 8b10b K codes
constant K28_0	: std_logic_vector(7 downto 0) := "00011100";
constant K28_1	: std_logic_vector(7 downto 0) := "00111100"; -- Link down
constant K28_2	: std_logic_vector(7 downto 0) := "01011100";
constant K28_3	: std_logic_vector(7 downto 0) := "01111100";
constant K28_4	: std_logic_vector(7 downto 0) := "10011100";
constant K28_5	: std_logic_vector(7 downto 0) := "10111100"; -- Link up, data valid
constant K28_6	: std_logic_vector(7 downto 0) := "11011100";
constant K28_7	: std_logic_vector(7 downto 0) := "11111100"; -- Link up, data not valid
constant K23_7	: std_logic_vector(7 downto 0) := "11110111"; 
constant K27_7	: std_logic_vector(7 downto 0) := "11111011"; -- Link Error
constant K29_7	: std_logic_vector(7 downto 0) := "11111101";
constant K30_7	: std_logic_vector(7 downto 0) := "11111110";
		
		


end defs;



