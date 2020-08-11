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
use IEEE.STD_LOGIC_ARITH.ALL;
use IEEE.STD_LOGIC_UNSIGNED.ALL;
use work.defs.all;
use work.components.all;



entity ACC_main is
	port(		
		clockIn			: in	clockSource_type;
		clockCtrl		: out	clockCtrl_type;
		LVDS_In			: in	LVDS_inputArray_type;
		LVDS_Out			: out LVDS_outputArray_type;		
		syncOut  		: out	std_logic;			
		led            : out	std_logic_vector(2 downto 0); -- red(2), yellow(1), green(0)				
		SMA				: inout	std_logic_vector(1 to 6);	
		USB_in			: in USB_in_type;
		USB_out			: out USB_out_type;
		USB_bus			: inout USB_bus_type;
		DIPswitch		: in   std_logic_vector (9 downto 0)		-- switch reads as a 10-bit binary number msb left (sw1), lsb right (sw10); switch open = logic 1		
	);
end ACC_main;
	
	
	
architecture vhdl of	ACC_main is


	signal	ledSetup				: 	ledSetup_array_type;
	signal	ledDrv				: 	std_logic_vector(2 downto 0);
	signal	clock					: 	clock_type;
	signal	reset					: 	reset_type;
	signal	usbTx					:	usbTx_type;
	signal	usbRx					:	usbRx_type;
	signal	uartTx				:	uartTx_type;
	signal	uartRx				:	uartRx_type;
	signal	trigSetup			:	trigSetup_type;
	signal	trig					:	trig_type;
   signal   usb_busWriteEnable: std_logic_vector(15 downto 0);
   signal   usb_busReadEnable: std_logic;   
   signal   rxBuffer_readReq: std_logic;
   signal   rxBuffer_resetReq: std_logic;
   signal   timestamp_resetReq : std_logic;
   signal   localInfo_readReq : std_logic;
   signal   localInfo_latchReq : std_logic;
   signal   softTrig: std_logic_vector(N-1 downto 0);
   signal   softTrigBin : std_logic_vector(2 downto 0);
   signal   readMode	: std_logic_vector(2 downto 0);
   signal   waitForSys	: std_logic;
   signal   dataHandler_timeoutError: std_logic;
   signal   sync:       std_logic;
   signal   localInfo:  frameData_type;
   signal	systemTime:	std_logic_vector(47 downto 0);
   signal   binCount:   std_logic_vector(15 downto 0);
   signal   eventCount: eventCount_type;
   signal   timestamp: timestamp_type;
	signal	trigToCount :	std_logic;
	
	
	
begin




------------------------------------
--	LED INDICATOR SETTINGS
------------------------------------

-- led index (front panel):	
--
--	2 red
-- 1 yellow
-- 0 green


-- modes:
-- 
-- ledMode.flashing
-- ledMode.monostable
-- ledMode.direct
--
--
-- led setup: (input, mode, onTime[ms], period[ms])
--
ledSetup(2) <= (input => usbTx.valid		, mode => ledMode.monostable, onTime => 100, period => 100);
ledSetup(1) <= (input => usbRx.valid		, mode => ledMode.monostable, onTime => 100, period => 100);
ledSetup(0) <= (input => reset.global		, mode => ledMode.flashing, onTime => 50, period => 100);


LED_driver_gen: for i in 0 to 2 generate
	LED_driver_map: LED_driver port map (
		clock	 	=> clock.timer,        
		setup		=> ledSetup(i),
		output   => ledDrv(i));
	-- leds are inverse logic so invert the outputs
	led(i) <= not ledDrv(i);
end generate;








------------------------------------
--	UART COMMS
------------------------------------
-- serial comms with the acdc
uart_comms_8bit_gen	:	 for i in N-1 downto 0 generate
	uart_comms_8bit_map : uart_comms_8bit
	port map(
		reset					=> reset.global,	--global reset
		clock					=> clock,  
		txIn					=> uartTx.word,
		txIn_valid			=> uartTx.valid and uartTx.enable(i),	
		txOut					=> uartTx.serial(i),
		rxIn					=> uartRx.serial(i), 
		rxOut					=> uartRx.word(i),
		rxOut_valid			=> uartRx.valid(i),
		rxWordAlignReset 	=> uartRx.bufferReset(i),		-- reset rx so the next byte received is lower 8 bits of 16 bit word
		rxError				=> uartRx.error(i));
	end generate;
	
		
     

		
		

------------------------------------
--	RESET
------------------------------------

RESET_PROCESS : process(clock.sys)
-- perform a hardware reset by setting the ResetOut signal high for the time specified by ResetLength and then low again
-- any ResetRequest inputs will restart the process
variable t: natural := 0;		-- elaspsed time counter
variable r: std_logic;
begin
	if (rising_edge(clock.sys)) then 				
		if (reset.request = '1') then t := 0; end if;   -- restart counter if new reset request					 										
		if (t >= 40000000) then r := '0'; else r := '1'; t := t + 1; end if;
		reset.global <= r;
	end if;
end process;


      


      
------------------------------------
--	CLOCKS
------------------------------------

clockGen_map: ClockGenerator Port map(
		clockIn			=> clockIn,		-- clock sources into the fpga
		clockCtrl		=> clockCtrl,
		clock				=> clock			-- the generated clocks for use by the rest of the firmware
	);		


   
      

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


LVDS_GEN: process(trig, uartTx.serial, LVDS_In)
begin
	for i in N-1 downto 0 loop
-- out
		LVDS_Out(i)(0) <=	uartTx.serial(i);
		LVDS_Out(i)(1) <=	trig.output(i);
		LVDS_Out(i)(2) <=	'0';
-- in
		uartRx.serial(i) <= LVDS_In(i)(0);
	end loop;
end process;





------------------------------------
--	COMMAND HANDLER
------------------------------------
-- takes the command word and generates the appropriate control & setup signals
CMD_HANDLER_MAP: commandHandler port map (
		reset						=> reset.global,
		clock				      => clock.sys,      
      din		      	   => usbRx.data,
      din_valid				=> usbRx.valid,
      localInfo_readReq    => localInfo_readReq,
		rxBuffer_resetReq    => rxBuffer_resetReq,
		timestamp_resetReq   => timestamp_resetReq,
		globalResetReq       => reset.request,
      trigSetup            => trigSetup,
      softTrig             => softTrig,
		softTrigBin 			=> softTrigBin,
      readMode             => readMode,
      syncOut     			=> sync,
		extCmd.enable     	=> uartTx.enable,    -- an 8 bit field that selects the board(s) to which the command will be sent
		extCmd.data       	=> uartTx.word,
		extCmd.valid         => uartTx.valid,
      waitForSys  			=> waitForSys);

  

------------------------------------
--	DATA HANDLER
------------------------------------
-- manages the various sources of data & information 
-- and the transmission of this data over usb, 
-- according to request signals received
DATA_HANDLER_MAP: dataHandler port map (
		reset			=> reset.global,
		clock			=> clock.sys,
		readMode    => readMode,		
      ramReadEnable  => uartRx.ramReadEn,
      ramAddress     => uartRx.ramAddress,
      ramData        => uartRx.ramDataOut,
      rxDataLen		=> uartRx.dataLen,
      bufferReadoutDone => uartRx.ramReadDone,  -- byte wide, one bit for each channel
      dout 		         => usbTx.data,
		dout_valid			=> usbTx.valid,
      txAck             => usbTx.dataAck,
      txReady           => usbTx.ready,
      txLockReq         => usbTx.lockReq,
      txLockAck         => usbTx.lockAck,
      localInfo_readRequest=> localInfo_readReq,    
		localInfo				=> localInfo,
      linkStatusOk        	=> uartRx.linkStatusOk,
      trigInfo             => trigSetup.source,
      rxPacketStarted      => uartRx.packetStarted,
      rxPacketReceived     => uartRx.packetReceived,
      timeoutError  			=> dataHandler_timeoutError);
  

LOCAL_INFO_REG: process(clock.sys)
begin
if (rising_edge(clock.sys)) then
		localInfo(0) <= binCount; 
		localInfo(1) <= eventCount.trig(31 downto 16);
		localInfo(2) <= eventCount.trig(15 downto 0);
		localInfo(3) <= timestamp.trig(15 downto 0);
		localInfo(4) <= timestamp.trig(31 downto 16);
		localInfo(5) <= timestamp.trig(47 downto 32);
		localInfo(6) <= uartTx.word(31 downto 16);
end if;
end process;
  
   
	 
	 
	 
	 
------------------------------------
--	UART LINK STATUS CHECK
------------------------------------
 -- ACC requests a short frame from all acdc channels
 -- whichever ones respond are flagged as present
 ACDC_Detect_process: process(clock.sys)
 begin
	if (rising_edge(clock.sys)) then
		for i in 0 to N-1 loop
			if (reset.global = '1' or uartRx.error(i) = '1' or rxBuffer_resetReq = '1') then
				uartRx.linkStatusOk(i) <= '0';
			elsif (uartRx.packetReceived(i) = '1') then
				uartRx.linkStatusOk(i) <= '1';
			end if;
		end loop;
	end if;
end process;	
 
 
 
 
 
 
 
 
------------------------------------
--	TRIGGER 
------------------------------------
TRIG_AND_TIME: triggerAndTime port map (
	clock						=> clock,
	reset 					=> reset.global,
	extTrig					=> SMA(6),
	trigReset				=> reset.global or rxBuffer_resetReq,
	trigSetup				=> trigSetup,
	trigToCount				=> trigToCount,
	SOFT_TRIG_IN			=> softTrig,
	CC_READ_MODE     	=> readMode,	
	AUX_TRIG_0				=> '0',
	AUX_TRIG_1				=> '0',
	AUX_TRIG_2_DC			=> '0',
	AUX_TRIG_3_DC			=> '0',
	ACDC_WAITING			=> waitForSys,
	EVENT_AND_TIME_RESET	=> timestamp_resetReq,
	TRIG_FROM_FRONTEND	=> x"00",	
	SLAVE_DEV_HARD_RESET => '0',
	SOFT_TRIG_BIN			=> softTrigBin,	
	MASTERHI_SLAVELO		=> '1',
	FROM_SYSTEM_TRIGGER 	=> '0',
	TRIG_OUT					=> trig.output,
	CLOCKED_TRIG_OUT		=> open,
	xBIN_COUNT				=> binCount,
	AUX_TRIG_COUNTERS		=> open);
  
  

------------------------------------
--	UART RX BUFFER
------------------------------------
-- stores a burst of received data in ram
uart_rxBuffer_gen	:	 for i in N-1 downto 0 generate
	uart_rxBuffer_map : uart_rxBuffer
	port map (
		reset				=> uartRx.bufferReset(i),-- need to get this signal from data handler
		clock				=> clock.sys,	--system clock		 
		din				=> uartRx.word(i), --data in, 16 bits
		din_valid		=> uartRx.valid(i),	 
		packetStarted  => uartRx.packetStarted(i),	--flag that a data packet from front-end was received
		packetReceived	=> uartRx.packetReceived(i),
		read_enable		=> uartRx.ramReadEn(i), 	--enable reading from RAM block
		read_address	=> uartRx.ramAddress,--ram address
		dataLen		   => uartRx.dataLen(i), -- length of data stored in ram
		dout				=> uartRx.ramDataOut(i)--data out
		);	
end generate;


uart_rxBuffer_reset_gen: 
process(reset.global, rxBuffer_resetReq, uartRx.ramReadDone)
begin
	for i in N-1 downto 0 loop
		uartRx.bufferReset(i) <= reset.global or rxBuffer_resetReq or uartRx.ramReadDone(i);
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
usbTx_gen: usbTx_driver
	port map (
			clock   		=> clock,
			reset    	=> reset.global,	   --reset signal to usb block
			txLockReq  	=> usbTx.lockReq,  
			txLockAck  	=> usbTx.lockAck,
			txLockAvailable => (not usbRx.busy) and (not usbRx.dataAvailable),--  tx can be locked when high; check flag as well as busy to ensure it doesn't get stuck in a loop where they both wait for each other  
			din	   	=> usbTx.data,  --data bus from firmware
			din_valid 	=> usbTx.valid,
			txReady   	=> usbTx.ready,
			txAck      	=> usbTx.dataAck,
         bufferReady => usb_in.CTL(2), -- usb flag c meaning the usb chip is ready to accept tx data  (note this flag is on usb clock)  	
         PKTEND      => usb_bus.PA(6),		--usb packet end flag
			SLWR     	=> usb_out.RDY(1),     --slave bus write signal to usb chip
         txBusy  		=> usbTx.busy,     --usb write-busy indicator (not a PHY pin)
			dout			=> usbTx.dataOut,
         timeoutError => usbTx.timeoutError);
        
        
usb_bus.PA(7) <= '0'; --SLCS signal, the slave chip select (permanently enabled)
------------------------------------
--	USB RX 
------------------------------------
-- reads 32-bit words from the usb port
-- processing is done with usb clock but output data is on system clock
usbRx_gen: usbRx_driver
	port map (
			clock			  => clock, 
			reset		     => reset.global, 	   --reset signal to usb block
			din  		     => usbRx.dataIn,  --usb data bus to PHY
         busReadEnable => usb_busReadEnable,
         enable        => not usbTx.busy, -- can't tx and rx at the same time as there is only one bus
         dataAvailable => usbRx.dataAvailable, -- FLAG A      (note this flag is on usb clock)
         SLOE          => usb_bus.PA(2),      -- slave bus output enable,   
         SLRD          => usb_out.RDY(0),		--usb slave bus read enable
         FIFOADR       => usb_bus.PA(5 downto 4),			
         busy 		     => usbRx.busy,	--usb read-busy indicator (not a PHY pin)
         dout          => usbRx.data,     -- 32bit data to the command handler
			dout_valid    => usbRx.valid,		--flag hi = packet read from PC is ready				
         timeoutError  => usbRx.timeoutError);

usbRx.dataAvailable <= usb_in.CTL(0);
       
         
------------------------------------
--	USB BUS DRIVER
------------------------------------
-- tristate control of the usb bus for reading and writing
usb_io_buffer	: iobuf
	port map(
		datain	=>	usbTx.dataOut,	-- tx data to the usb chip bus
		oe			=> usb_busWriteEnable,	-- low = read from bus, high = write to bus
		dataio	=> usb_bus.FD,	         -- the 16-bit wide bidirectional data bus of the Cypress chip
		dataout	=> usbRx.dataIn); -- data from the usb chip
      
usb_bus_oe: process(usb_busReadEnable)
begin
	for i in 15 downto 0 loop
		usb_busWriteEnable(i) <= not usb_busReadEnable;
	end loop;
end process;

         
      


		
------------------------------------
--	SYSTEM TIME
------------------------------------
sysTime_map: systemTime_driver port map(

	clock					=>	clock,
	reset					=> reset.global,
	trig					=> trigToCount,
	eventAndTime_reset => timestamp_resetReq,
	systemTime			=> open,		
	timestamp			=> timestamp,		
	eventCount			=> eventCount);





			
         
 
 
end vhdl;
