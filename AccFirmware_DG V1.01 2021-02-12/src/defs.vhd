---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         defs.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;

package defs is


	
type firmwareVersion_type is record
	number : std_logic_vector(15 downto 0);
	year : std_logic_vector(15 downto 0);
	MMDD:	std_logic_vector(15 downto 0);
end record;



--------------------------------
-- VERSION INFO
--
-- update when changes are made
--
--------------------------------
-- numbers are bcd format (i.e. 0 to 9 only)
--
constant firwareVersion: firmwareVersion_type:= (
	
	number => 	x"0101", 
	year => 		x"2021",	
	MMDD => 		x"0212"		-- month, date		
	
);
--
--
-- Revision history
--
-- V0017 15 Oct 2020 Initial version
-- V0100 31 Jan 2021 Added auto-detect ext clock option
-- V0101 12 Feb 2021 Added new mode, mode 9 which triggers from the pps signal on the 'system' lvds connector
--------------------------------






constant N	:	natural := 8; --number of front-end boards (either 4 or 8, depending on RJ45 port installation)



--RAM specifiers for uart receiver buffer
constant	transceiver_mem_depth	:	integer := 15; --ram address size
constant	transceiver_mem_width	:	integer := 16; --data size


--type definitions
type rx_ram_data_type is array(N-1 downto 0) of	std_logic_vector(transceiver_mem_width-1 downto 0);
type LVDS_inputArray_type is array(N-1 downto 0) of std_logic_vector(3 downto 0);
type LVDS_outputArray_type is array(N-1 downto 0) of std_logic_vector(2 downto 0);
type Array_8bit is array(N-1 downto 0) of std_logic_vector(7 downto 0);
type Array_16bit is array(N-1 downto 0) of std_logic_vector(15 downto 0);
type frameData_type is array(31 downto 0) of std_logic_vector(15 downto 0);
type naturalArray_16bit is array(N-1 downto 0) of natural range 0 to 65535;
type natArray2 is array(N-1 downto 0) of natural range 0 to 3;


--defs for the SERDES links
constant STARTWORD				: 	std_logic_vector := x"1234";
constant STARTWORD_8a			: 	std_logic_vector := x"B7";
constant STARTWORD_8b			: 	std_logic_vector := x"34";
constant ENDWORD					: 	std_logic_vector := x"4321";
constant ALIGN_WORD_16 			: 	std_logic_vector := x"FACE";
constant ALIGN_WORD_8 			:  std_logic_vector := x"CE";





	
	
------------------------------------
--	CLOCKS
------------------------------------

type clockCtrl_type is record
	clockSourceSelect	:	std_logic;
end record;



type clockSource_type is record
	localOsc		:	std_logic;
	usb_IFCLK	:	std_logic;	-- 48MHz
end record;


type clock_type is record
	sys			:	std_logic;
   x4	         :	std_logic;
   uart        :	std_logic;  
   usb         :	std_logic;  
	timer			:	std_logic;
   altpllLock  :	std_logic;  
end record;





------------------------------------
--	SYSTEM IO (lvds)
------------------------------------

type systemIn_type is record
	in0	:	std_logic;
	in1	:	std_logic;
end record;

type systemOut_type is record
	out0	:	std_logic;
end record;






------------------------------------
--	EXTERNAL COMMAND
------------------------------------

type extCmd_type is record
	enable     : 	std_logic_vector(7 downto 0);
	data       : 	std_logic_vector(31 downto 0);
	valid		  : 	std_logic;
end record;



	
------------------------------------
--	LEDS
------------------------------------

type LEDmode_type is record
	direct		: natural;
	monostable	: natural;
	flashing		: natural;
end record;


constant ledMode: LEDmode_type:= (1,2,3);		-- arbitrary numbers to identify different modes

type LEDsetup_type is record
	input:			std_logic;
	mode:				natural;
	period:			natural;
	onTime:			natural;
end record;
	
type LEDtestSetup_type is record
	source:			natural;
	onTime:			natural;
	enable:			std_logic;
end record;
	
	
		
-- (led index, mode)
type ledSetup_array_type is array (0 to 8, 0 to 3) of ledSetup_type;
type ledFunction_array is array (0 to 8) of natural range 0 to 3;
type ledTestFunction_array is array (0 to 8) of natural range 0 to 255;
type ledTest_onTime_array is array (0 to 8) of natural range 0 to 4095;

	
	
------------------------------------
--	RESET
------------------------------------
type reset_type is record
	global		:	std_logic;
	request		:	std_logic;
end record;







------------------------------------
--	TRIGGER
------------------------------------
type trigSetup_type is record
	enable		: std_logic_vector(7 downto 0);
	source		: natArray2;
	sw				: std_logic;
end record;





------------------------------------
--	UART TX
------------------------------------
type uartTx_type is record
	word				:	std_logic_vector(31 downto 0);
	valid				:	std_logic;
	enable			:	std_logic_vector(N-1 downto 0);
   serial         :	std_logic_vector(N-1 downto 0);
end record;





------------------------------------
--	UART RX
------------------------------------
type uartRx_type is record
	dataLen    		:	naturalArray_16bit;
	serial	   	:	std_logic_vector(N-1 downto 0);
	word		   	:	Array_16bit;
	valid				:	std_logic_vector(N-1 downto 0);
	error				:	std_logic_vector(N-1 downto 0);
	bufferReset		:	std_logic_vector(N-1 downto 0);
	buffer_not_empty:	std_logic_vector(N-1 downto 0);
	linkStatusOk	:	std_logic_vector(N-1 downto 0);
	ramReadEn 		:std_logic_vector(N-1 downto 0);
	ramReadDone 	:std_logic_vector(N-1 downto 0);
	ramAddress		:	std_logic_vector(transceiver_mem_depth-1 downto 0);--ram address
	ramDataOut		:rx_ram_data_type;
end record;

	
	
------------------------------------
--	USB 
------------------------------------

type USB_in_type is record			-- note: usb IFCLK input is covered by 'clockSource' type
	CTL		: std_logic_vector(2 downto 0);
	CLKOUT	: std_logic;
	WAKEUP	: std_logic;
end record;


type USB_out_type is record
	RDY	: std_logic_vector(1 downto 0);
end record;


type USB_bus_type is record
	FD	: std_logic_vector(15 downto 0);
	PA	: std_logic_vector(7 downto 0);
end record;

	
		
------------------------------------
--	USB TX
------------------------------------
type usbTx_type is record
	lockReq			:	std_logic;
	lockAck			:	std_logic;
	data				:	std_logic_vector(15 downto 0);
	dataOut			:	std_logic_vector(15 downto 0);
	dataAck			:	std_logic;
   ready	         :	std_logic;
   valid	         :	std_logic;
   busy	         :	std_logic;
   timeoutError   :	std_logic;
	dataTransferDone:	std_logic;
end record;




------------------------------------
--	USB RX
------------------------------------
type usbRx_type is record
	busy				:	std_logic;
	data				:	std_logic_vector(31 downto 0);
	dataIn			:	std_logic_vector(15 downto 0);
	valid				:	std_logic;
	dataAvailable	:	std_logic;
   timeoutError	:	std_logic;
end record;






end defs;



