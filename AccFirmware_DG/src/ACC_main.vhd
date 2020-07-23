---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
--
-- PROJECT:      ANNIE 
-- FILE:         ACC_main.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020
--
-- DESCRIPTION:  top-level firmware module for ACC
--
---------------------------------------------------------------------------------


library IEEE; 
use ieee.std_logic_1164.all;
USE ieee.numeric_std.ALL; 
use work.defs.all;
use work.components.all;



entity ACC_main is
	port(	
	
		clockIn			: in	std_logic_vector(3 downto 0);
		clockSwCtrl		: out	std_logic;
		LVDS_In			: in	LVDS_inputArray_type;
		LVDS_Out			: out LVDS_outputArray_type;		
		syncOut  		: out	std_logic;			
		led            : out	std_logic_vector(2 downto 0); -- red(2), yellow(1), green(0)				
		SMA				: inout	std_logic_vector(1 to 6);	

	-- usb controller CY7C68013A	
		usb_FD  		   : inout  std_logic_vector (15 downto 0);  --usb data bus to PHY
		usb_PA  		   : inout  std_logic_vector (7 downto 0);  
		usb_CTL    		: in     std_logic_vector(2 downto 0);     
		usb_RDY    		: out    std_logic_vector(1 downto 0);     
		usb_CLKOUT		: in	 std_logic;   	
		usb_IFCLK		: in	 std_logic;   	--usb clock 48 Mhz
      usb_WAKEUP  	: in    std_logic;					
		
	-- misc
		DIPswitch		: in   std_logic_vector (9 downto 0)		-- switch reads as a 10-bit binary number msb left (sw1), lsb right (sw10); switch open = logic 1
		
);
end ACC_main;
	
	
	
architecture vhdl of	ACC_main is



-- reset
	constant resetLen				:  natural:= 40000000;  -- the reset length in clock cycles
	signal	reset_global		:	std_logic;
	signal	reset_request		:	std_logic;
	
-- clocks
	signal	clock_1Hz			:	std_logic;
	signal	clock_40MHz			:	std_logic;
	signal	clock_160MHz		:	std_logic;
   signal   sysClk            :	std_logic;
   signal   uartClk           :	std_logic;
   signal   trigClk           :	std_logic;
   signal   usbClk            :	std_logic;  
   
-- trigger
	signal	trig				   : std_logic_vector(N-1 downto 0);
   
-- uart tx
	signal	uartTx_word		   :	std_logic_vector(31 downto 0);
	signal	uartTx_word_valid	:	std_logic;
	signal	uartTx_enable     :  std_logic_vector(N-1 downto 0);
	signal	uartTx_serial	   :	std_logic_vector(N-1 downto 0);

-- uart rx 
	signal	uartRx_dataLen    :	naturalArray_16bit;
	signal	uartRx_serial	   :	std_logic_vector(N-1 downto 0);
	signal	uartRx_word		   :	Array_16bit;
	signal	uartRx_word_valid	:	std_logic_vector(N-1 downto 0);
	signal	uartRx_error		:	std_logic_vector(N-1 downto 0);
	signal	uartRx_bufferReset:	std_logic_vector(N-1 downto 0);
	signal	uartRx_linkStatusOk :	std_logic_vector(N-1 downto 0);
	signal	uartRx_ramReadEn :std_logic_vector(N-1 downto 0);
	signal	uartRx_ramReadDone :std_logic_vector(N-1 downto 0);
	signal	uartRx_ramAddress:	std_logic_vector(transceiver_mem_depth-1 downto 0);--ram address
	signal	uartRx_ramDataOut:rx_ram_data_type;
	signal	uartRx_packetReceived:std_logic_vector(N-1 downto 0);
	signal	uartRx_packetStarted:std_logic_vector(N-1 downto 0);   
   
-- usb
   signal   usb_busWriteEnable: std_logic_vector(15 downto 0);
   signal   usb_busReadEnable: std_logic;   
   signal   usb_SLCS: std_logic;   
   
-- usb tx
   signal   usbTx_dataValid: std_logic;		 
   signal   usbTx_dataAck: std_logic;		
   signal   usbTx_ready: std_logic;		
   signal   usbTx_pktEndReq: std_logic;
   signal   usbTx_data: std_logic_vector(15 downto 0); 
   signal   usbTx_dataOut: std_logic_vector(15 downto 0); --usb data bus to PHY
   signal   usbTx_fifoEmpty: std_logic;		--usb flag c 
   signal   usbTx_PKTEND: std_logic;		--usb packet end flag
   signal   usbTx_SLWR: std_logic;		--usb slave interface write signal
   signal   usbTx_busy: std_logic; 	   --usb done with write cycle to PC flag
   signal   usbTx_dataClock: std_logic;		--usb signal-low write (generated clock)
   signal   usbTx_lockReq: std_logic; 
   signal   usbTx_lockAck: std_logic;    
   signal   usbTx_dataIn: std_logic_vector(15 downto 0);  --data bus from firmware
   signal   usbTx_timeoutError: std_logic;	

-- usb rx
   signal   usbRx_dataIn: std_logic_vector(15 downto 0); --usb data bus to PHY
   signal   usbRx_dataAvailable: std_logic;     --usb flag a
   signal   usbRx_SLOE: std_logic;    	--usb signal-low output enable
   signal   usbRx_SLRD: std_logic;		--usb signal-low read (generated clock)
   signal   usbRx_FIFOADR: std_logic_vector(1 downto 0);			
   signal   usbRx_busy: std_logic;	--usb read-busy indicator (not a PHY pin)
   signal   usbRx_dataOut: std_logic_vector(31 downto 0);
   signal   usbRx_dataOutValid: std_logic;		--flag hi = packet read from PC is ready				
   signal   usbRx_timeoutError: std_logic;	

-- command
   signal   rxBuffer_readReq: std_logic;
   signal   rxBuffer_resetReq: std_logic;
   signal   timestamp_resetReq : std_logic;
   signal   localInfo_readReq : std_logic;
   signal   localInfo_latchReq : std_logic;
   
-- setup
   signal   trigMode: std_logic;
   signal   trigDelay: std_logic_vector(6 downto 0);
   signal   trigValid: std_logic;
   signal   trigSource	: std_logic_vector(2 downto 0);
   signal   softTrig: std_logic_vector(N-1 downto 0);
   signal   softTrigBin : std_logic_vector(2 downto 0);
   signal   readMode	: std_logic_vector(2 downto 0);
   signal   waitForSys	: std_logic;
 
--misc
   signal   ledFunction : std_logic_vector(15 downto 0);
   signal   ledMonoIn : std_logic_vector(2 downto 0);
   signal   ledMonoOut : std_logic_vector(2 downto 0);
   signal   ledNorm : std_logic_vector(2 downto 0);
   signal   ledMonoNorm : std_logic_vector(2 downto 0);
   signal   lastErrorCode:  natural;
   signal   dataHandler_timeoutError: std_logic;
   signal   sync:       std_logic;
   signal   localInfo:  frameData_type;
   signal   systemTime: std_logic_vector(47 downto 0);
   signal   binCount:   std_logic_vector(15 downto 0);
   signal   eventCount: std_logic_vector(31 downto 0);
   signal   alignLvdsFlag: std_logic;
   
   
   signal	test_data_valid: std_logic;
   signal	test_txValid: std_logic;
   signal	test_txPulse: std_logic;
	
	
	
begin


------------------------------------
--	LED INDICATORS
------------------------------------
----- note leds are inverted, i.e. logic 0 = on, logic 1 = off
led <= reset_global & "10";




--Temporary to force link status ok on board 0
uartRx_linkStatusOk <= "00000001";




------------------------------------
--	UART COMMS
------------------------------------
-- serial comms with the acdc
-- contains 8b10b encoding/decoding and link status check	
uart_comms_8bit_gen	:	 for i in N-1 downto 0 generate
	uart_comms_8bit_map : uart_comms_8bit
	port map(
		reset					=> reset_global,	--global reset
		uart_clock			=> uartClk,  --clock for communications
		sys_clock			=> sysClk,	--system clock
		txIn					=> uartTx_word,
		txIn_valid			=> uartTx_word_valid and uartTx_enable(i),	
		txOut					=> uartTx_serial(i),
		rxIn					=> uartRx_serial(i), 
		rxOut					=> uartRx_word(i),
		rxOut_valid			=> uartRx_word_valid(i),
		rxWordAlignReset 	=> uartRx_bufferReset(i),		-- reset rx so the next byte received is lower 8 bits of 16 bit word
		rxError				=> uartRx_error(i));
	end generate;
	
		
      



------------------------------------
--	USB SIGNAL-to-PIN MAPPING
------------------------------------

-- inputs from usb chip
usbRx_dataAvailable  <= usb_CTL(0); -- FLAG A      (note this flag is on usb clock)
usbTx_fifoEmpty      <= usb_CTL(2); -- FLAG C      (note this flag is on usb clock)  

-- outputs to usb chip
usb_PA(6) <= usbTx_PKTEND;    -- packet end
usb_RDY(1) <= usbTx_SLWR;     -- slave bus write
usb_PA(2) <= usbRx_SLOE;      -- slave bus output enable
usb_RDY(0) <= usbRx_SLRD;     -- slave bus read
usb_PA(7) <= usb_SLCS;		-- slave bus chip select
usb_PA(5 downto 4) <= usbRx_FIFOADR;   -- fifo select (i.e. rx or tx fifo)
usb_SLCS <= '0';	-- permanently enable the chip's slave interface to the fpga



------------------------------------
--	RESET
------------------------------------
RESET_PROCESS : process(sysClk)
-- perform a hardware reset by setting the ResetOut signal high for the time specified by ResetLength and then low again
-- any ResetRequest inputs will restart the process
variable t: natural := 0;		-- elaspsed time counter
begin
	if (rising_edge(sysClk)) then 				
		if (reset_request = '1') then t := 0; end if;   -- restart counter if new reset request					 										
		if (t >= resetLen) then 
			reset_global <= '0'; 
		else
			reset_global <= '1'; t := t + 1;
		end if;
	end if;
end process;


      
------------------------------------
--	CLOCKS
------------------------------------
CLOCK_GEN : clockGenerator port map(
		INCLK				=> clockIn(0),
		CLK_SYS_4x		=> clock_160MHz, 		
		CLK_SYS			=> clock_40MHz,
		ClockOut_1Hz	=> clock_1Hz);

clockSwCtrl <= '0';      
      
sysClk <= clock_40MHz;
uartClk <= clock_160MHz;
trigClk <= clock_160MHz;
usbClk <= usb_IFCLK; -- from the usb chip crystal oscillator, 48MHz
            
      

------------------------------------
--	SYNC
------------------------------------
syncOut <= sync;



------------------------------------
--	LVDS 
------------------------------------

--  LVDS_In(channel)(0)  = uart rx serial data in
--  LVDS_In(channel)(1)  = not used
--  LVDS_In(channel)(2)  = not used
--  LVDS_In(channel)(3)  = not used
--
--  LVDS_Out(channel)(0) = uart tx data out
--  LVDS_Out(channel)(1) = trigger out
--  LVDS_Out(channel)(2) = not used
--  LVDS_Out(channel)(3) = system clk out (bypasses FPGA, no FPGA pin assignment)


LVDS_GEN: process(trig, uartTx_serial, uartRx_serial, LVDS_In)
begin
	for i in N-1 downto 0 loop
-- out
		LVDS_Out(i)(0) <=	uartTx_serial(i);
		LVDS_Out(i)(1) <=	trig(i);
		LVDS_Out(i)(2) <=	'0';
-- in
		uartRx_serial(i) <= LVDS_In(i)(0);
	end loop;
end process;



------------------------------------
--	COMMAND HANDLER
------------------------------------
-- takes the command word and generates the appropriate control & setup signals
CMD_HANDLER_MAP: commandHandler port map (
		reset						=> reset_global,
		clock				      => sysClk,      
      din		      	   => usbRx_dataOut,
      din_valid				=> usbRx_dataOutValid,
      localInfo_readReq    => localInfo_readReq,
		rxBuffer_resetReq    => rxBuffer_resetReq,
		timestamp_resetReq   => timestamp_resetReq,
		globalResetReq       => reset_request,
      trigMode             => trigMode,
      trigDelay				=> trigDelay,
		trigSource				=> trigSource,
		trigValid            => trigValid,
      softTrig             => softTrig,
		softTrigBin 			=> softTrigBin,
      readMode             => readMode,
      syncOut     			=> sync,
		extCmd_enable     	=> uartTx_enable,    -- an 8 bit field that selects the board(s) to which the command will be sent
		extCmd_data       	=> uartTx_word,
		extCmd_valid         => uartTx_word_valid,
		alignLvdsFlag        => alignLvdsFlag,
      waitForSys  			=> waitForSys);

  

------------------------------------
--	DATA HANDLER
------------------------------------
-- manages the various sources of data & information 
-- and the transmission of this data over usb, 
-- according to request signals received
DATA_HANDLER_MAP: dataHandler port map (
		reset			=> reset_global,
		clock			=> sysClk,
		readMode    => readMode,		
      ramReadEnable  => uartRx_ramReadEn,
      ramAddress     => uartRx_ramAddress,
      ramData        => uartRx_ramDataOut,
      rxDataLen		=> uartRx_dataLen,
      bufferReadoutDone => uartRx_ramReadDone,  -- byte wide, one bit for each channel
      dout 		         => usbTx_data,
		dout_valid			=> usbTx_dataValid,
      txAck             => usbTx_dataAck,
      txReady           => usbTx_ready,
      txLockReq         => usbTx_lockReq,
      txLockAck         => usbTx_lockAck,
      localInfo_readRequest=> localInfo_readReq,    
		localInfo				=> localInfo,
      linkStatusOk         => uartRx_linkStatusOk,
      trigInfo             => trigSource,
      rxPacketStarted      => uartRx_packetStarted,
      rxPacketReceived     => uartRx_packetReceived,
      timeoutError  			=> dataHandler_timeoutError);
  

LOCAL_INFO_REG: process(sysClk)
begin
if (rising_edge(sysClk)) then
		localInfo(0) <= binCount; 
		localInfo(1) <= eventCount(31 downto 16);
		localInfo(2) <= eventCount(15 downto 0);
		localInfo(3) <= systemTime(15 downto 0);
		localInfo(4) <= systemTime(31 downto 16);
		localInfo(5) <= systemTime(47 downto 32);
		localInfo(6) <= uartTx_word(31 downto 16);
end if;
end process;
  
    
  
------------------------------------
--	TRIGGER AND TIME
------------------------------------
TRIG_AND_TIME: triggerAndTime port map (
	sys_clock				=> sysClk,
	reset 					=> reset_global,
	xEXT_TRIGGER			=> SMA(6),
	xTRIG_CLK				=> trigClk,
	xUSB_DONE				=> reset_global or rxBuffer_resetReq,
	xMODE						=> trigMode,
	xTRIG_DELAY				=> trigDelay,
	xSOFT_TRIG_IN			=> softTrig,
	xCC_READ_MODE     	=> readMode,	
	xAUX_TRIG_0				=> '0',
	xAUX_TRIG_1				=> '0',
	xAUX_TRIG_2_DC			=> '0',
	xAUX_TRIG_3_DC			=> '0',
	XACDC_WAITING			=> waitForSys,
	xEVENT_AND_TIME_RESET=> timestamp_resetReq,
	xTRIG_FROM_FRONTEND	=> x"00",	
	xTRIG_SOURCE      	=> trigSource,
	xSLAVE_DEV_HARD_RESET => '0',
	xEXT_TRIG_VALID		=> trigValid,
	xSOFT_TRIG_BIN			=> softTrigBin,	
	xMASTERHI_SLAVELO		=> '1',
	xFROM_SYSTEM_TRIGGER => '0',
	xTRIG_OUT				=> trig,
	xSYSTEM_CLOCK_COUNTER=> systemTime,
	xEVENT_COUNT			=> eventCount,
	xCLOCKED_TRIG_OUT		=> open,
	xBIN_COUNT				=> binCount,
	xAUX_TRIG_COUNTERS	=> open);
  
  

------------------------------------
--	UART RX BUFFER
------------------------------------
-- stores a burst of received data in ram
uart_rxBuffer_gen	:	 for i in N-1 downto 0 generate
	uart_rxBuffer_map : uart_rxBuffer
	port map (
		reset				=> uartRx_bufferReset(i),-- need to get this signal from data handler
		clock				=> sysClk,	--system clock		 
		din				=> uartRx_word(i), --data in, 16 bits
		din_valid		=> uartRx_word_valid(i),	 
		packetStarted  => uartRx_packetStarted(i),	--flag that a data packet from front-end was received
		packetReceived	=> uartRx_packetReceived(i),
		read_enable		=> uartRx_ramReadEn(i), 	--enable reading from RAM block
		read_address	=> uartRx_ramAddress,--ram address
		dataLen		   => uartRx_dataLen(i), -- length of data stored in ram
		dout				=> uartRx_ramDataOut(i)--data out
		);	
end generate;


uart_rxBuffer_reset_gen: 
process(reset_global, uartRx_linkStatusOk, rxBuffer_resetReq, uartRx_ramReadDone)
begin
	for i in N-1 downto 0 loop
		uartRx_bufferReset(i) <= reset_global or (not uartRx_linkStatusOk(i)) or rxBuffer_resetReq or uartRx_ramReadDone(i);
	end loop;
end process;
	
	
 
------------------------------------
--	USB TX 
------------------------------------
-- writes 16-bit words to the usb port
-- also contains the tristate bus driver with read data output and bus read enable control
-- transfers I/O signals to the sys clock for easier interfacing
--
-- note there is no 'done' signal as previously used (although there is a dataAck) because 
-- this module no longer handles the processing of a whole frame of data, 
-- it only takes in one word at a time
usbTx_gen: usbTx
	port map (
			usb_clock   => usbClk,   	--usb clock 48 Mhz
			sys_clock   => sysClk,   	
			reset    	=> reset_global,	   --reset signal to usb block
			txLockReq  	=> usbTx_lockReq,  
			txLockAck  	=> usbTx_lockAck,
			txLockAvailable => (not usbRx_busy) and (not usbRx_dataAvailable),--  tx can be locked when high; check flag as well as busy to ensure it doesn't get stuck in a loop where they both wait for each other  
			din	   	=> usbTx_data,  --data bus from firmware
			din_valid 	=> usbTx_dataValid,
			txReady   	=> usbTx_ready,
			txAck      	=> usbTx_dataAck,
         bufferReady => usbTx_fifoEmpty,		--usb flag c meaning the usb chip is ready to accept tx data
         PKTEND      => usbTx_PKTEND,		--usb packet end flag
			SLWR     	=> usbTx_SLWR,       --slave write signal to usb chip
         txBusy  		=> usbTx_busy,     --usb write-busy indicator (not a PHY pin)
			dout			=> usbTx_dataOut,
         timeoutError => usbTx_timeoutError);
        
        

------------------------------------
--	USB RX 
------------------------------------
-- reads 32-bit words from the usb port
-- processing is done with usb clock but output data is on system clock
usbRx_gen: usbRx
	port map (
			usb_clock	  => usbClk,   	--usb processing clock 48 Mhz
			sys_clock	  => sysClk,   	--system clock for synchronizing output data
			reset		     => reset_global, 	   --reset signal to usb block
			din  		     => usbRx_dataIn,  --usb data bus to PHY
         busReadEnable => usb_busReadEnable,
         enable        => not usbTx_busy, -- can't tx and rx at the same time as there is only one bus
         dataAvailable => usbRx_dataAvailable,     --usb flag a
         SLOE          => usbRx_SLOE,    	--usb slave bus output enable
         SLRD          => usbRx_SLRD,		--usb slave bus read enable
         FIFOADR       => usbRx_FIFOADR,			
         busy 		     => usbRx_busy,	--usb read-busy indicator (not a PHY pin)
         dout          => usbRx_dataOut,     -- 32bit data to the command handler
			dout_valid    => usbRx_dataOutValid,		--flag hi = packet read from PC is ready				
         timeoutError  => usbRx_timeoutError);

         
         
------------------------------------
--	USB BUS DRIVER
------------------------------------
-- tristate control of the usb bus for reading and writing
usb_io_buffer	: iobuf
	port map(
		datain	=>	usbTx_dataOut,	-- tx data to the usb chip bus
		oe			=> usb_busWriteEnable,	-- low = read from bus, high = write to bus
		dataio	=> usb_FD,	         -- the 16-bit wide bidirectional data bus of the Cypress chip
		dataout	=> usbRx_dataIn); -- data from the usb chip
      
usb_bus_oe: process(usb_busReadEnable)
begin
	for i in 15 downto 0 loop
		usb_busWriteEnable(i) <= not usb_busReadEnable;
	end loop;
end process;

         
      














		

			
         
 
 
end vhdl;
