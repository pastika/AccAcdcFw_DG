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

constant firmware_version : std_logic_vector := x"0017";


constant N:	natural:= 5;	-- the number of PSEC4 chips on the ACDC card
constant M:	natural:= 6;	-- the number of channels on each PSEC4 chip



--defs for the SERDES links
constant STARTWORD				: 	std_logic_vector := x"1234";
constant STARTWORD_8a			: 	std_logic_vector := x"B7";
constant STARTWORD_8b			: 	std_logic_vector := x"34";
constant ENDWORD					: 	std_logic_vector := x"4321";
constant ALIGN_WORD_16 			: 	std_logic_vector := x"FACE";
constant ALIGN_WORD_8 			:  std_logic_vector := x"CE";
constant PSEC_END_WORD 			:  std_logic_vector := x"FACE";


--type defs

type info_type is array (4 downto 0, 0 to 13) of std_logic_vector(15 downto 0);




constant WILKRAMPCOUNT	: integer   := 160; --set ramp length w.r.t. clock
constant RAM_ADR_SIZE  	: integer   := 14;
constant SETFREQ      	: std_logic := '0';
constant VBIAS_INITAL	 		:	std_logic_vector := x"800";
constant TRIG_THRESH_INITIAL	:	std_logic_vector := x"FFF";



type natArray32 	is array (N-1 downto 0) of natural;
type natArray24 	is array (N-1 downto 0) of natural range 0 to 16777215;
type natArray16	is array (N-1 downto 0) of natural range 0 to 65535;
type natArray12 	is array (N-1 downto 0) of natural range 0 to 4095;

type wordArray	is array (N-1 downto 0) of std_logic_vector(15 downto 0);
type array32 	is array (N-1 downto 0) of std_logic_vector(31 downto 0);
type array24 	is array (N-1 downto 0) of std_logic_vector(23 downto 0);
type array16 	is array (N-1 downto 0) of std_logic_vector(15 downto 0);
type array12 	is array	(N-1 downto 0) of	std_logic_vector(11 downto 0);
type array6 	is array (N-1 downto 0) of std_logic_vector(5 downto 0);
type array4 	is array	(N-1 downto 0) of std_logic_vector(3 downto 0);	
type array3 	is array	(N-1 downto 0) of std_logic_vector(2 downto 0);	
type bitArray 	is array (N-1 downto 0) of std_logic;	
type trigger_array 		is array (5 downto 0) of 	std_logic_vector(15 downto 0);
type rate_count_array 	is array	(M*N-1 downto 0) of	std_logic_vector (15 downto 0);


constant RO: natArray16:= (16#CA00#, 16#CA00#, 16#CA00#, 16#CA00#, 16#CA00#);




------------------------------------
--	CLOCKS
------------------------------------

type clockSource_type is record
	localOsc		:	std_logic;
	jcpll			:	std_logic;
end record;


type jcpll_ctrl_type is record
	spi_latchEnable	:	std_logic;
	spi_mosi				:	std_logic;
	spi_clock			:	std_logic;
	testMode				:	std_logic;
	pllSync				:	std_logic;
	powerDown			:	std_logic;
	refSelect			:	std_logic;
end record;


type clock_type is record
	sys			:	std_logic;
   dac         :	std_logic;
   uart        :	std_logic;
   trig        :	std_logic;
   usb         :	std_logic;  
	timer			:	std_logic;
	update		:	std_logic;
   pllLock     :	std_logic;  
end record;






------------------------------------
--	COMMAND
------------------------------------
type cmd_type is record
	word		:	std_logic_vector(31 downto 0);
	valid		:	std_logic;
end record;




------------------------------------
--	DAC
------------------------------------

type DAC_type is record
	serialData	: std_logic;
	serialClock	: std_logic;
	load			: std_logic;
	clear			: std_logic;	-- active low
end record;


type DAC_array_type is array (0 to 2) of DAC_type;


type serialDAC_type is record
	dataSize		: natural;
	channels		: natural;
	maxValue		: natural;
end record;


-------------------------------------
constant serialDAC: serialDAC_type:= 
(
	dataSize => 12,
	channels => 8,
	maxValue => 4095
);
-------------------------------------


type dacData_type is array (0 to 7) of natural range 0 to serialDAC.maxValue;
type DACchain_data_type is array (0 to 1) of dacData_type;		-- 2 devices in each chain
type DACchain_data_array_type is array (0 to 2) of DACchain_data_type;		-- 3 chains
type dacWordArray_type is array (0 to N-1) of natural range 0 to serialDAC.maxValue;





------------------------------------
--	LEDS
------------------------------------
constant numberOfLEDs: natural := 9;

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
	


	
	
	
	
		
type ledSetup_array_type is array (0 to 10) of ledSetup_type;







------------------------------------
--	PSEC4 
------------------------------------

type PSEC4_in_type is record
	data			: std_logic_vector(11 downto 0);
	overflow		: std_logic;
	ringOsc_mon	: std_logic;
	DLL_clock	: std_logic;
	trig			: std_logic_vector(5 downto 0);
end record;


type PSEC4_out_type is record
	DLLreset_n	: std_logic;
	trigClear	: std_logic;
	rampStart	: std_logic;
	readClock	: std_logic;
	extTrig		: std_logic;
	ADCclear		: std_logic;
	ringOsc_enable	: std_logic;
	ADClatch		: std_logic;
	channel		: natural range 0 to M-1;
	TokDecode	: std_logic_vector(2 downto 0);
	TokIn			: std_logic_vector(1 downto 0);
end record;



type PSEC4_in_array_type is array (0 to N-1) of PSEC4_in_type;
type PSEC4_out_array_type is array (0 to N-1) of PSEC4_out_type;






------------------------------------
--	RESET
------------------------------------
type reset_type is record
	global		:	std_logic;
	request		:	std_logic;
	len			:	natural;
end record;





------------------------------------
--	SELF TRIG
------------------------------------
type selfTrigSetting_type is array (1 downto 0) of std_logic_vector(10 downto 0);

type selfTrig_type is record
	mask				:	std_logic_vector(N*M-1 downto 0);
	setting			:	selfTrigSetting_type;
	reset				:	std_logic;
   rates	         :	rate_count_array;
   sig	       	:	std_logic_vector(M*N-1 downto 0);
   sign	        	:	std_logic;
   clear	       	:	std_logic;  
   enable        	:	std_logic;
   latchedOR     	:	std_logic_vector(1 to 3);
   latched       	:	std_logic_vector(M*N-1 downto 0);
   rateCount      :	rate_count_Array;
	internal			:	array6;
end record;





------------------------------------
--	TRIGGER
------------------------------------
type trigInfo_type is array (1 to 3, 0 to 4) of std_logic_vector(15 downto 0);


type trig_type is record
	fromAcc				:	std_logic;
	fromDigitalCard	:	std_logic;
	valid					:	std_logic;
	output				:	std_logic;
   reg	        		:	std_logic_vector(2 downto 0);
   reset	        		:	std_logic;
   flag	       		:	std_logic;  
   clear	       		:	std_logic;  
	info					:	trigInfo_type;
	threshold			:	array12;
end record;




------------------------------------
--	UART TX
------------------------------------
type uartTx_type is record
	byte				:	std_logic_vector(7 downto 0);
	valid				:	std_logic;
	serial			:	std_logic;
   ready	         :	std_logic;
   dataAck       	:	std_logic;
	dataTransferDone:	std_logic;
end record;




------------------------------------
--	UART RX
------------------------------------
type uartRx_type is record
	serial			:	std_logic;
	byte				:	std_logic_vector(7 downto 0);
	valid				:	std_logic;
   error	         :	std_logic;
end record;




------------------------------------
--	USB 
------------------------------------

type USB_in_type is record
	CTL		: std_logic_vector(2 downto 0);
	CLKOUT	: std_logic;
	IFCLK		: std_logic;
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
	word				:	std_logic_vector(7 downto 0);
	valid				:	std_logic;
	serial			:	std_logic;
   ready	         :	std_logic;
   dataAck       	:	std_logic;
	dataTransferDone:	std_logic;
end record;




------------------------------------
--	USB RX
------------------------------------
type usbRx_type is record
	serial			:	std_logic;
	word				:	std_logic_vector(7 downto 0);
	valid				:	std_logic;
   error	         :	std_logic;
end record;
















end defs;






























