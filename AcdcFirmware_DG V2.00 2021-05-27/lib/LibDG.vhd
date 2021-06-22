---------------------------------------------------------------------------------
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020         
--
-- DESCRIPTION:  library component definitions
--
---------------------------------------------------------------------------------


library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_arith.all;
use ieee.std_logic_unsigned.all;


package LibDG is

		
		
component pulseGobbler is
	Port(
		clock		: in	std_logic;
		input		: in	std_logic;
		N			: in natural;
		output	: out std_logic
		);
end component;
		
		
component pulseSync is
   port (
		inClock     : in std_logic;
      outClock    : in std_logic;
		din_valid	: in	std_logic;       
      dout_valid  : out std_logic);
		
end component;
      
      
component fastCounter64 is
	PORT
	(
		clock		:	IN	STD_LOGIC;
		reset		:	in	std_logic;
		q			: 	out std_logic_vector(63 downto 0)
	);
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







component monostable_sync_level is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;
   
	
	
component monostable_sync_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;



component monostable_async_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : out std_logic);
end component;



component monostable_asyncio_edge is
	port (
		clock	      : in std_logic;        
		len         : in natural;
		trig        : in std_logic;
		output      : buffer std_logic);
end component;
  
   

component risingEdgeDetect is
	port (
		clock	      : in std_logic;        
		input        : in std_logic;
		output      : out std_logic);
end component;




component fallingEdgeDetect is
	port (
		clock	      : in std_logic;        
		input        : in std_logic;
		output      : out std_logic);
end component;





end LibDG;























