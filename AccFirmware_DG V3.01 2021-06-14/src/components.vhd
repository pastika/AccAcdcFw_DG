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


component serialTx_buffer is
  port (
    clock      : in  std_logic;
    eth_clk    : in  std_logic;
    din        : in  std_logic_vector(31 downto 0);
    din_txReq  : in  std_logic;
    dout       : out std_logic_vector(7 downto 0);
    dout_txReq : out std_logic;
    dout_txAck : in  std_logic);
end component serialTx_buffer;


component serialRx_buffer is
  port (
    reset        : in  std_logic;
    clock        : in  std_logic;
    eth_clk      : in  std_logic;
    din          : in  std_logic_vector(7 downto 0);
    din_valid    : in  std_logic;
    read_enable  : in  std_logic;
    buffer_empty : out std_logic;
    dataLen      : out std_logic_vector(15 downto 0);
    dout         : out std_logic_vector(15 downto 0)); 
end component serialRx_buffer;


component txFifo is
  port (
    data    : IN  STD_LOGIC_VECTOR (31 DOWNTO 0);
    rdclk   : IN  STD_LOGIC;
    rdreq   : IN  STD_LOGIC;
    wrclk   : IN  STD_LOGIC;
    wrreq   : IN  STD_LOGIC;
    q       : OUT STD_LOGIC_VECTOR (31 DOWNTO 0);
    rdempty : OUT STD_LOGIC;
    wrfull  : OUT STD_LOGIC);
end component txFifo;

		
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
		outclk_2 : out std_logic;        -- outclk1.clk
		locked   : out std_logic         --  locked.export
	);
end component;
	
		
		
component ClockGenerator is
	Port(
		clockIn		: in	clockSource_type;
		clock			: buffer clock_type;
		pps			: in std_logic;
		resetRequest: out std_logic;
		useExtRef	: buffer std_logic
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
    reset         : in  std_logic;
    clock         : in  clock_type;
    eth_clk       : in  std_logic;
    rx_addr       : in  std_logic_vector (31 downto 0);
    rx_data       : in  std_logic_vector (63 downto 0);
    rx_wren       : in  std_logic;
    tx_data       : out std_logic_vector (63 downto 0);
    tx_rden       : in  std_logic;
    config        : out config_type;
    regs          : in  readback_reg_type;
    ledPreset     : in	LEDPreset_type;
    extCmd        : out extCmd_type;
    serialRX_data : in  Array_16bit;
    serialRX_rden : out std_logic_vector(N-1 downto 0));
end component commandHandler;


component commandSync is
  port (
    reset     : in  std_logic;
    clock     : in  clock_type;
    eth_clk   : in  std_logic;
    eth_reset : in  std_logic;
    config_z  : in  config_type;
    config    : out config_type;
    reg       : in  readback_reg_type;
    reg_z     : out readback_reg_type);
end component commandSync;


component dataHandler is
	port (
		reset						: 	in   	std_logic;
		clock				      : 	in		std_logic;        
		serialRx					:	in		serialRx_type;
		pllLock					:  in std_logic;
		trig						: in trigSetup_type;
		channel          		: in natural;
      ramReadEnable        : 	out 	std_logic_vector(7 downto 0);
      ramAddress           :  out   std_logic_vector(transceiver_mem_depth-1 downto 0);
      ramData              :  in    rx_ram_data_type;
      rxDataLen				:  in  	naturalArray_16bit;
		frame_received    	:  in   std_logic_vector(7 downto 0);
      bufferReadoutDone    :  buffer  std_logic_vector(7 downto 0);
      dout 		            : 	out	std_logic_vector(15 downto 0);
		txReq					   : 	out	std_logic;
      txAck                : 	in 	std_logic;
      txLockReq            : 	out	std_logic;
      txLockAck            : 	in  	std_logic;
		rxBuffer_readReq		:	in	std_logic;
      localInfo_readRequest: in std_logic;      
      acdcBoardDetect      : in std_logic_vector(7 downto 0);    
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


component rx_data_fifo is
  port (
    aclr    : IN  STD_LOGIC := '0';
    data    : IN  STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdclk   : IN  STD_LOGIC;
    rdreq   : IN  STD_LOGIC;
    wrclk   : IN  STD_LOGIC;
    wrreq   : IN  STD_LOGIC;
    q       : OUT STD_LOGIC_VECTOR (15 DOWNTO 0);
    rdempty : OUT STD_LOGIC;
    rdusedw : OUT STD_LOGIC_VECTOR (8 DOWNTO 0);
    wrfull  : OUT STD_LOGIC);
end component rx_data_fifo;


component ethernet_adapter is
  port (
    clock        : in    clock_type;
    reset        : in    std_logic;
    ETH_in       : in    ETH_in_type;
    ETH_out      : out   ETH_out_type;
    ETH_mdc      : inout std_logic;
    ETH_mdio     : inout std_logic;
    user_addr	 : in    std_logic_vector (7 downto 0);
    eth_clk      : out   std_logic;
    rx_addr      : out   std_logic_vector (31 downto 0);
    rx_data      : out   std_logic_vector (63 downto 0);
    rx_wren      : out   std_logic;
    tx_data      : in    std_logic_vector (63 downto 0);
    tx_rden      : out   std_logic;
    b_data       : in    std_logic_vector (63 downto 0);
    b_data_we    : in    std_logic;
    b_data_force : in    std_logic;
    b_enable     : out   std_logic); 
end component ethernet_adapter;


component ETH_pll is
  port (
    refclk   : in  std_logic := '0';
    rst      : in  std_logic := '0';
    outclk_0 : out std_logic;
    outclk_1 : out std_logic;
    locked   : out std_logic);
end component ETH_pll;


component eth_clk_ctrl is
  port (
    inclk  : in  std_logic := '0'; --  altclkctrl_input.inclk
    outclk : out std_logic         -- altclkctrl_output.outclk
	);
end component eth_clk_ctrl;






component usbDriver is
   port ( 		
		clock   					: in		std_logic;
		rxData_in	  	  	 	: in     std_logic_vector (15 downto 0);  --usb data from PHY
		txData_out				: out    std_logic_vector (15 downto 0);  --usb data bus to PHY
      txBufferReady 			: in  	std_logic;		--the tx buffer on the chip is ready to accept data 
      rxDataAvailable  		: in    	std_logic;     --usb data received flag
      busWriteEnable 		: out   	std_logic;     --when high the fpga outputs data onto the usb bus
      PKTEND  					: out 	std_logic;		--usb packet end flag
      SLWR		      	  	: buffer 	std_logic;		--usb slave interface write signal
      SLOE         			: buffer   	std_logic;    	--usb slave interface bus output enable, active low
		SLRD     	   		: buffer   	std_logic;		--usb  slave interface bus read, active low
      FIFOADR  	   		: out   	std_logic_vector (1 downto 0); -- usb endpoint fifo select, essentially selects the tx fifo or rx fifo
		tx_busReq  				: in		std_logic;  -- request to lock the bus in tx mode, preventing any interruptions from usb read
		tx_busAck  				: out		std_logic;  
      txData_in        		: in   	std_logic_vector(15 downto 0);		
      txReq		        		: in   	std_logic;		
      txAck		        		: out   	std_logic;		
      rxData_out       		: out   	std_logic_vector(31 downto 0);
		rxData_valid     		: out		std_logic;
		test						: out		std_logic_vector(15 downto 0)
);
end component;




	component iobuf
	port(
		datain		: IN 		STD_LOGIC_VECTOR (15 DOWNTO 0);
		oe				: IN  	STD_LOGIC_VECTOR (15 DOWNTO 0);
		dataio		: INOUT 	STD_LOGIC_VECTOR (15 DOWNTO 0);
		dataout		: OUT 	STD_LOGIC_VECTOR (15 DOWNTO 0));
	end component;

   
   
   
   
   
   
   
   
   
end components;























