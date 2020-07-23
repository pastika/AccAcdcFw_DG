---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         components.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         June 2020         
--
-- DESCRIPTION:  component definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;
use work.defs.all;


package components is

		
		
		
--------------------		
-- system components
--------------------


component pll is
	port (
		inclk0		: IN STD_LOGIC  := '0';
		c0		: OUT STD_LOGIC ;
		c1		: OUT STD_LOGIC ;
		c2		: OUT STD_LOGIC ;
		locked		: OUT STD_LOGIC 
	);
end component;
	
		
		
component ClockGenerator is
	Port(
		reset			:	in		std_logic;
		clockIn		: 	in 	clockSource_type;				
		jcpll			:	out 	jcpll_ctrl_type;
		altpllLock	:	out	std_logic;
		clock			: 	out 	clock_type
	);
end component;
		
		
		

	
      
      
      
      
      
------------------------------------------		
-- command & data processing components
------------------------------------------



component commandHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
      din		      	   :  in    std_logic_vector(31 downto 0);
      din_valid				:  in    std_logic;
		trigThreshold			: out natArray16;    
		Vbias						: out natArray16;   
		DLL_Vdd					: out natArray16;    
		calEnable				: out std_logic_vector(14 downto 0);   
		eventAndTime_reset	: out std_logic;   
		reset_request			: out std_logic;   
		DLL_resetRequest		: out std_logic;   
		selfTrig_reset			: out std_logic;   
		selfTrigMask			: out std_logic_vector(29 downto 0);     
		selfTrigSetting		: out selfTrigSetting_type;   
		RO_target				: out natArray16; 
		ramReadRequest			: out std_logic;   
		enableLED				: out std_logic;   
		PLL_sampleMode			: out std_logic_vector(1 downto 0);       
		trigValid 				: out std_logic;   
		CC_event_RESET			: out std_logic
		);
end component;


component dataHandler is
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
end component;
		
		
component dataRam IS
	PORT
	(
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (13 DOWNTO 0);
		wraddress		: IN STD_LOGIC_VECTOR (13 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0)
	);
END component;
		
      
		
component LED_driver is
	port (
		clock	      : in std_logic;        
		setup			: in ledSetup_type;
		output      : out std_logic
	);
end component;
		
		
------------------------------------------		
-- PSEC4 channel
------------------------------------------

component PSEC4_channel is
	port(	
	
		clock					: in	clock_type;
		adcStart				: in 	std_logic;
		adcReset				: in 	std_logic;
		reset					: in  reset_type;
		PSEC4_in				: in 	PSEC4_in_type;
		DLL_reset			: in  std_logic;
		Wlkn_fdbk_target	: in  natural range 0 to 65535;

		PSEC4_out			: out PSEC4_out_type;
		VCDL_count			: out	natural;
		DAC_value			: out natural range 0 to 4095;
		Wlkn_fdbk_current : out natural range 0 to 65535;
		DLL_monitor			: out std_logic
	);
	
end component;


component dataBuffer is 
	port(	

		PSEC4_in : in	PSEC4_in_type;		
		readClk :  OUT  STD_LOGIC;
		channel :  OUT  natural range 0 to M-1;
		Token :  OUT  STD_LOGIC_VECTOR(1 DOWNTO 0);	
		blockSelect : out natural;	
		readClock: out std_logic;
		
		clock					:	in		std_logic;   	--40MHz clock from jitter cleaner
		reset					:	in		std_logic;	--transfer done
		rampDone				:  in		std_logic;
		ramReadAddress		:	in		natural; 
		ramDataOut			:	out	std_logic_vector(11 downto 0);	--13 bit RAM-stored data	
		done					:	out	std_logic);	-- the psec data has been read out and stored in ram
		
		
end component;
      
      
component DAC_driver is
	port(	
	
		process_clock	: in	std_logic;
		update_clock	: in	std_logic;
		reset				: in	std_logic;
		trigThreshold	:	in array12;
		Vbias				:	in	array12;
		pro_vdd			:  in array12;
		dll_vdd			:	in	array12;		
		dac_out			:	out DAC_array_type
);
end component;
	
      
component psec4_trigger_GLOBAL is
	port(
			xTRIG_CLK				: in 	std_logic;   --fast clk (320MHz) to trigger all chans once internally triggered
			xMCLK						: in	std_logic;   --ext trig sync with write clk
			reset					: in	std_logic;   --wakeup reset (clears high)
			xDONE						: in	std_logic;	-- USB done signal					
			xCC_TRIG					: in	std_logic;   -- trig over LVDS
			xDC_TRIG					: in	std_logic;   -- on-board SMA input			
			xSELFTRIG 				: in	array6;  	--internal trig sgnl			
			xSELF_TRIGGER_MASK	: in 	std_logic_vector(29 downto 0);
			xSELF_TRIGGER_SETTING: in	selfTrigSetting_type; --open dataspace for config of this block
			xRESET_TRIG_FLAG		: in	std_logic;
			xDLL_RESET				: in	std_logic;
			xPLL_LOCK				: in	std_logic;
			xTRIG_VALID   			: in	std_logic;
			xDONE_FROM_SYS			: in	std_logic;
			xRESET_TIMESTAMPS		: in	std_logic;			
			xTRIGGER_OUT			: out	std_logic;
			xSTART_ADC				: out std_logic;
			xTRIG_SIGNAL_REG		: out	std_logic_vector(2 downto 0);			
			xSELFTRIG_CLEAR		: out	std_logic;			
			xRATE_ONLY           : out std_logic;			
			xPSEC4_TRIGGER_INFO	: out trigInfo_type;
			xSAMPLE_BIN				: out	std_logic_vector(3 downto 0);
			xSELF_TRIG_RATES		: out rate_count_array;
			xSELF_TRIG_SIGN		: out std_logic);
	end component;



component psec4_SELFtrigger is
	port(
			reset						: in	std_logic;   --wakeup reset (clears high)
			xDONE						: in	std_logic;	
			xTRIG_CLK				: in  std_logic;

			xRESET_FROM_FIRM		: in	std_logic;
			xSELF_TRIGGER			: in	std_logic_vector(29 downto 0);
			
			xSELF_TRIG_CLEAR		: in	std_logic;
			xSELF_TRIG_ENABLE		: in	std_logic;
			xSELF_TRIG_MASK		: in	std_logic_vector(29 downto 0);
			
			xSELF_TRIG_LATCHEDOR1: out std_logic;
			xSELF_TRIG_LATCHEDOR2: out std_logic;
			xSELF_TRIG_LATCHEDOR3: out std_logic;
			xSELF_TRIG_LATCHED	: out std_logic_vector(29 downto 0));
			
end component;


component Wilkinson_Feedback_Loop is
        Port (
          ENABLE_FEEDBACK     : in std_logic;
          RESET_FEEDBACK      : in std_logic;
          REFRESH_CLOCK       : in std_logic; --One period of this clock defines how long we count Wilkinson rate pulses
          DAC_SYNC_CLOCK      : in std_logic; --This clock should be the same that is used for setting DACs, and should be used to avoid race conditions on setting the desired DAC values
          WILK_MONITOR_BIT    : in std_logic;
          DESIRED_COUNT_VALUE : in natural range 0 to 65535;
          CURRENT_COUNT_VALUE : out natural range 0 to 65535;
          DESIRED_DAC_VALUE   : out natural range 0 to 4095
        );
end component;

	
component VCDL_Monitor_Loop is
        Port (
                                RESET_FEEDBACK      : in std_logic;
                                clock			       : in std_logic; --One period of this clock defines how long we count Wilkinson rate pulses
                                VCDL_MONITOR_BIT    : in std_logic;
                                countReg				 : out natural
        );
end component;


component ADC_Ctrl is 
	port(
		sysClock			:	in		std_logic;			--40MHz	
		updateClock		:	in		std_logic;			--10Hz	
		reset				:	in		std_logic;
		trigFlag			:	in		std_logic;
		RO_EN 			:	out	std_logic;
		adcClear			:	out	std_logic;
		adcLatch			:	out	std_logic
);
end component;


component dacSerial is
  port(
        clock           : in    std_logic;      -- DAC clk ( < 50MHz ) 
        update			   : in    std_logic;
        dataIn          : in    DACchain_data_type;  	-- array (0 to 1) of dac data
        dac    	      : out   dac_type);
end component;


   
--------------------		
-- uart components
--------------------
      
      
      
component rxCommand IS 
	PORT
	(
		reset 				:  IN  STD_LOGIC;
		clock 				:  IN  clock_type;
		din 					:  IN  STD_LOGIC_VECTOR(7 DOWNTO 0);
		din_valid			:  IN  STD_LOGIC;
		dout 					:  OUT STD_LOGIC_VECTOR(31 DOWNTO 0);	-- instruction word out
		dOut_valid			:  OUT STD_LOGIC
	);
END component;
      
      
      
      


COMPONENT uart
	GENERIC ( dataLen			: natural:= 8;
				 clockDivRatio : natural:= 8 );
	PORT
	(
		clock				:	 IN STD_LOGIC;
		reset				:	 IN STD_LOGIC;
		txData			:	 IN STD_LOGIC_VECTOR(dataLen-1 DOWNTO 0);
		txData_valid	:	 IN STD_LOGIC;
		txData_ack		:	 OUT STD_LOGIC;
		txReady			:	 OUT STD_LOGIC;
		txOut				:	 OUT STD_LOGIC;
		rxData			:	 OUT STD_LOGIC_VECTOR(dataLen-1 DOWNTO 0);
		rxData_valid	:	 OUT STD_LOGIC;
		rxError 			:	 OUT STD_LOGIC;
		rxIn				:	 IN STD_LOGIC
	);
END COMPONENT;












--------------------		
-- usb components
--------------------


component usbTx is
   port ( 	
			usb_clock   : in		std_logic;   	--usb clock 48 Mhz
			sys_clock   : in		std_logic;   	
			reset	      : in  	std_logic;	   --reset signal to usb block
			txLockReq    	: in		std_logic;  
			txLockAck    	: out		std_logic;  
			txLockAvailable 	: in		std_logic;  
			din	   	: in		std_logic_vector (15 downto 0);  
			din_valid  	: in		std_logic;  
         txReady   	: out		std_logic;  
         txAck     	: out		std_logic;  
         bufferReady : in  	std_logic;		--the tx buffer on the chip is ready to accept data 
         PKTEND      : out 	std_logic;		--usb packet end flag
         SLWR        : out 	std_logic;		--usb packet end flag
         txBusy  		: out 	std_logic;     --usb write-busy indicator (not a PHY pin)
			dout			: out    std_logic_vector (15 downto 0);  --usb data bus to PHY
         timeoutError: out    std_logic);
end component;




component usbRx is
   port ( 
		usb_clock		: in		std_logic;   	--usb clock 48 Mhz
		sys_clock		: in		std_logic;   
		reset		      : in  	std_logic;	   --reset signal to usb block
		din  		      : in     std_logic_vector (15 downto 0);  --usb data from PHY
      busReadEnable 	: out   	std_logic;     --when high disables drive to usb bus thus enabling reading
      enable       	: in    	std_logic;     --
      dataAvailable  : in    	std_logic;     --usb data received flag
      SLOE         	: out   	std_logic;    	--usb bus output enable, active low
      SLRD     	   : out   	std_logic;		--usb bus read, active low
      FIFOADR  	   : out   	std_logic_vector (1 downto 0); -- usb endpoint fifo select			
      busy 		      : out   	std_logic;		--usb read-busy indicator (not a PHY pin)
      dout           : out   	std_logic_vector(31 downto 0);
		dout_valid     : out		std_logic;		--flag hi = packet read from PC is ready				
      timeoutError   : out    std_logic);
end component;




	component iobuf
	port(
		datain		: IN 		STD_LOGIC_VECTOR (15 DOWNTO 0);
		oe				: IN  	STD_LOGIC_VECTOR (15 DOWNTO 0);
		dataio		: INOUT 	STD_LOGIC_VECTOR (15 DOWNTO 0);
		dataout		: OUT 	STD_LOGIC_VECTOR (15 DOWNTO 0));
	end component;

   
   
   
   
   
   
   
   
   
   
  
----------------------------		
-- basic & test components
----------------------------

   
component monostable is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;
   
   
   
   component pulseSync is
   port (
		inClock     : in std_logic;
      outClock    : in std_logic;
		din_valid	: in	std_logic;       
      dout_valid  : out std_logic);
		
end component;
      
      
      
component timeoutTimer is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		enable      : in std_logic;
		expired     : out std_logic);
end component;
      


end components;























