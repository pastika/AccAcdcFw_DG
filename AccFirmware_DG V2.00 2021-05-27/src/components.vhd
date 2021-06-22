---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    
-- PROJECT:      ANNIE 
-- FILE:         components.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020         
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

		
		
component trigger is
	Port(
		clock		: in	std_logic;
		reset		: in std_logic;
		trig	 	: in trigSetup_type;		
		pps		: in std_logic;
		hw_trig	: in std_logic;
		beamGate_trig: in std_logic;
		trig_out		:  out std_logic_vector(7 downto 0)
		);
end component;



component pll is
	port (
		refclk   : in  std_logic := '0'; --  refclk.clk
		rst      : in  std_logic := '0'; --   reset.reset
		outclk_0 : out std_logic;        -- outclk0.clk
		outclk_1 : out std_logic;        -- outclk1.clk
		locked   : out std_logic         --  locked.export
	);
end component;
	
		
		
component ClockGenerator is
	Port(
		clockIn		: in	clockSource_type;
		clock			: buffer clock_type
	);
end component;
		
		
		
component ClockSelect is
	Port(
		clock		: in	clock_type;
		pps		: in std_logic;
		resetRequest: out std_logic;
		useExtRef: out std_logic
	);
end component;
	
	
		
     
      
component LED_driver is
	port (
		clock	      : in std_logic;        
		setup			: in ledSetup_type;
		output      : out std_logic
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
		boardDetect_resetReq	: 	out	std_logic;
		localInfo_readReq    :  out   std_logic;
		rxBuffer_resetReq    :  out   std_logic_vector(7 downto 0);
		rxBuffer_readReq		:	out	std_logic;
		globalResetReq       :  out   std_logic;
      trig		            :	out	trigSetup_type;
      readcHANNEL          :	out	natural range 0 to 15;
		ledFunction				:  out 	ledFunction_array;
		ledTestFunction		:  out 	ledTestFunction_array;
		ledTest_onTime			:  out 	ledTest_onTime_array;
		extCmd			      : 	out 	extCmd_type);
end component;


component dataHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
		pllLock					:  in std_logic;
		trig						: in trigSetup_type;
		readChannel          : in natural range 0 to 15;
      ramReadEnable        : 	out 	std_logic_vector(7 downto 0);
      ramAddress           :  out   std_logic_vector(transceiver_mem_depth-1 downto 0);
      ramData              :  in    rx_ram_data_type;
      rxDataLen				:  in  	naturalArray_16bit;
		frame_received    	:  in   std_logic_vector(7 downto 0);
      bufferReadoutDone    :  buffer  std_logic_vector(7 downto 0);
      dout 		            : 	out	std_logic_vector(15 downto 0);
		dout_valid			   : 	out	std_logic;
      txAck                : 	in 	std_logic;
      txReady              : 	in 	std_logic;
      txLockReq            : 	out	std_logic;
      txLockAck            : 	in  	std_logic;
		rxBuffer_readReq		:	in	std_logic;
      localInfo_readRequest: in std_logic;      
      acdcBoardDetect      : in std_logic_vector(7 downto 0);    
		pllLockFailCounter	: in natural;
		useExtRef				: in std_logic;   
      
      -- error
      timeoutError  			:	out	std_logic 
);
end component;
		
		
		
      
      
 


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
      read_enable		: in	std_logic; 	--enable reading from RAM block
		read_address	: in	std_logic_vector(transceiver_mem_depth-1 downto 0);--ram address
		buffer_empty	: out std_logic;
		frame_received	: buffer std_logic;
		dataLen			: out natural range 0 to 65535;
		dout				: out	std_logic_vector(transceiver_mem_width-1 downto 0)--ram data out
		);	
end component;






component uart_comms_8bit IS 
	PORT
	(
		reset 				:  IN  STD_LOGIC;
		clock 				:  IN  clock_type;
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


component usbTx_driver is
   port ( 	
			clock   		: in		clock_type;
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




component usbRx_driver is
   port ( 
		clock   			: in		clock_type;
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

   
   
   
   
   
   
   
   
   
end components;























