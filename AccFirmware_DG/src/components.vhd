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
		refclk   : in  std_logic := '0'; --  refclk.clk
		rst      : in  std_logic := '0'; --   reset.reset
		outclk_0 : out std_logic;        -- outclk0.clk
		outclk_1 : out std_logic         -- outclk1.clk
	);
end component;
	
		
		
component ClockGenerator is
	Port(
		INCLK		: in	std_logic;		
		CLK_SYS_4x	: out	std_logic;
		CLK_SYS		: out	std_logic; 
		clockOut_1Hz		: out	std_logic);		
end component;
		
		
		
	
      
component pulseSync is
   port (
		inClock     : in std_logic;
      outClock    : in std_logic;
		din_valid	: in	std_logic;       
      dout_valid  : out std_logic);
		
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
		localInfo_readReq     :  out   std_logic;
		rxBuffer_resetReq    :  out   std_logic;
		timestamp_resetReq   :  out   std_logic;
		globalResetReq       :  out   std_logic;
      trigMode             :	out	std_logic;
      trigDelay				:	out	std_logic_vector(6 downto 0);
		trigSource				:	out	std_logic_vector(2 downto 0);
		trigValid				:  out std_logic;
		softTrig            	:	out	std_logic_vector(N-1 downto 0);
		softTrigBin 			:	out	std_logic_vector(2 downto 0);
      readMode             :	out	std_logic_vector(2 downto 0);
		syncOut     			: 	out 	std_logic;
		extCmd_enable       : 	out 	std_logic_vector(7 downto 0);
		extCmd_data          : 	out	std_logic_vector(31 downto 0);
		extCmd_valid		   : 	out	std_logic;
		alignLvdsFlag			: out std_logic;
	  waitForSys  			:	out	std_logic);
end component;


component dataHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
		readMode             : in std_logic_vector(2 downto 0);
		
      -- rx buffer ram signals
      ramReadEnable        : 	out 	std_logic_vector(7 downto 0);
      ramAddress           :  out   std_logic_vector(transceiver_mem_depth-1 downto 0);
      ramData              :  in    rx_ram_data_type;
      rxDataLen				:  in  	naturalArray_16bit;
      bufferReadoutDone    :  out   std_logic_vector(7 downto 0);
      
      -- usb tx signals
      dout 		            : 	out	std_logic_vector(15 downto 0);
		dout_valid			   : 	out	std_logic;
      txAck                : 	in 	std_logic;
      txReady              : 	in 	std_logic;
      txLockReq            : 	out	std_logic;
      txLockAck            : 	in  	std_logic;
      
      -- local info
      localInfo_readRequest: in std_logic;      
		localInfo				: in frameData_type;
      linkStatusOk         : in std_logic_vector(7 downto 0);    
      trigInfo             : in std_logic_vector(2 downto 0);    
      rxPacketStarted      : in std_logic_vector(7 downto 0);    
      rxPacketReceived     : in std_logic_vector(7 downto 0);
      
      -- error
      timeoutError  			:	out	std_logic 
);
end component;
		
		
		
      
      
      
component triggerAndTime is
port(
	sys_clock				:  in		std_logic;
	reset 					: 	in		std_logic;
	xEXT_TRIGGER			:	in		std_logic;
	xTRIG_CLK				: 	in		std_logic;
	xUSB_DONE				:  in		std_logic;
	xMODE						: 	in		std_logic;
	xTRIG_DELAY				:  in		std_logic_vector(6 downto 0);
	xSOFT_TRIG_IN			:  in		std_logic_vector(N-1 downto 0);
	xCC_READ_MODE     	:  in		std_logic_vector(2 downto 0);
	
	xAUX_TRIG_0				:  in		std_logic;
	xAUX_TRIG_1				:  in		std_logic;
	xAUX_TRIG_2_DC			:	in		std_logic;
	xAUX_TRIG_3_DC			: 	in		std_logic;
	XACDC_WAITING			: 	in 	std_logic;
	
	xEVENT_AND_TIME_RESET:	in   	std_logic;
	
	xTRIG_FROM_FRONTEND	: 	in 	std_logic_vector(N-1 downto 0);
	
	
	xTRIG_SOURCE      	: 	in 	std_logic_vector(2 downto 0);
	xSLAVE_DEV_HARD_RESET : in 	std_logic;
	xEXT_TRIG_VALID		: 	in 	std_logic;
	xSOFT_TRIG_BIN			: 	in 	std_logic_vector(2 downto 0);
	
	xMASTERHI_SLAVELO		: 	in 	std_logic;
	xFROM_SYSTEM_TRIGGER : 	in 	std_logic;
	
	xTRIG_OUT				:  out	std_logic_vector(N-1 downto 0);	
	xSYSTEM_CLOCK_COUNTER:	out	std_logic_vector(47 downto 0);
	xEVENT_COUNT			:	out	std_logic_vector(31 downto 0);
	xCLOCKED_TRIG_OUT		: 	out 	std_logic;
	xBIN_COUNT				:  out   std_logic_vector(15 downto 0);
	xAUX_TRIG_COUNTERS	:  out	std_logic_vector(15 downto 0));
	
end component;
      
      
      
      
      
      
      
      
      
      
      


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




component rx_data_ram
	port (
		clock		: IN STD_LOGIC  := '1';
		data		: IN STD_LOGIC_VECTOR (15 DOWNTO 0);
		rdaddress		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		rden		: IN STD_LOGIC  := '1';
		wraddress		: IN STD_LOGIC_VECTOR (14 DOWNTO 0);
		wren		: IN STD_LOGIC  := '0';
		q		: OUT STD_LOGIC_VECTOR (15 DOWNTO 0));
end component;




component uart_rxBuffer is
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
end component;






component uart_comms_8bit IS 
	PORT
	(
		reset 				:  IN  STD_LOGIC;
		uart_clock 			:  IN  STD_LOGIC;
		sys_clock			:	IN  STD_LOGIC;
		txIn 					:  IN  STD_LOGIC_VECTOR(31 DOWNTO 0);
		txIn_valid 			:  IN  STD_LOGIC;
		txOut 				:  OUT STD_LOGIC;
		rxIn 					:  IN  STD_LOGIC;
		rxOut 				:  OUT STD_LOGIC_VECTOR(15 DOWNTO 0);
		rxOut_valid			:  OUT STD_LOGIC;
		rxWordAlignReset  :  in STD_LOGIC;
		rxError				:  OUT STD_LOGIC		-- can be used to request a retransmission
		
	);
END component;







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
   
   
   
   

end components;























