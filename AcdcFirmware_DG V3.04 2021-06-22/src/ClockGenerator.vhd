---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         clockGenerator.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         Oct 2020
--
-- DESCRIPTION:  generates different clock frequencies for the firmware using
-- 					an on-board pll and also an external jitter cleaning pll
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.pll;
use work.LibDG.pulseSync;
use work.defs.all;



entity ClockGenerator is
	Port(
		clockIn		: 	in 		clockSource_type;				
		jcpll			:	out 		jcpll_ctrl_type;
		clock			: 	buffer	clock_type
	);		
end ClockGenerator;


architecture vhdl of ClockGenerator is


-- constants 
-- set depending on osc frequency
constant TIMER_CLK_DIV_RATIO: natural:= 40000;	-- 40MHz / 40000 = 1kHz
constant SERIAL_CLK_DIV_RATIO: natural:= 1000;	-- 40MHz / 1000 = 40kHz	(exact freq is not too critical)



	signal serialClock	: std_logic;
	
begin




clock.usb <= clockIn.usb_IFCLK;



	
-- system clocks
PLL_MAP : pll port map
(
	inclk0	=>		clockIn.jcpll, 
	c0			=>		clock.sys, 		--	40MHz
	c1			=>		clock.x4,	-- 160MHz
	c2			=>		clock.x8,	-- 320MHz
	c3			=>		open,		-- 10MHz
	locked	=>		clock.altpllLock
);     
				


	
	
	
	
	
	
---------------------------------------
-- UPDATE CLOCK GENERATOR
---------------------------------------
WILK_CLK_GEN: process(clock.sys)
variable t: natural;
begin
	if (rising_edge(clock.sys)) then
		t := t + 1;
		if (t >= 4000000) then 	-- 100ms cycle time = 10Hz
			clock.update <= '1'; t := 0; 	
		else
			clock.update <= '0';
		end if;	
	end if;
end process;

	
	
	
	
	
	
	
---------------------------------------
-- JITTER CLEANER PROGRAMMING CLOCK GENERATOR
---------------------------------------
CLK_DIV_SERIAL: process(clockIn.localOsc)		
variable t: natural range 0 to 65535;
begin
	if (rising_edge(clockIn.localOsc)) then
		t := t + 1;
		if (t >= SERIAL_CLK_DIV_RATIO) then t := 0; end if;
		if (t >= SERIAL_CLK_DIV_RATIO /2) then serialClock <= '1'; else serialClock <= '0'; end if;
	end if;
end process;

	
	
	

	
---------------------------------------
-- JITTER CLEANER CONTROLLER	
---------------------------------------

	jcpll.testMode <= '1';			-- active low; leave this pin high
	jcpll.spi_clock <= serialClock;
	
	
	-- reference select
	-- 1 = Primary ref = lvds clock from ACC (normal operation)
	-- 0 = Secondary ref = on-board oscillator
	jcpll.refSelect <= '1';			


-------------------------------------------------------------------------------

	process(serialClock)

	type STATE_TYPE is ( IDLE, PWR_UP, WRITE_DATA, GND_STATE, SYNC); 
	variable state          : STATE_TYPE;	
	variable i	: natural;
	variable t	: natural:= 0;
	variable dataSel	: natural;
	variable data		: std_logic_vector(31 downto 0);
	
	begin
		if (falling_edge(serialClock)) then
		
			
		
			if (t < 40000) then
			
				jcpll.SPI_latchEnable <= '1';
				jcpll.powerDown <= '0';		-- active low
				jcpll.pllSync <= '0';
				dataSel := 0;
				state	:= PWR_UP;		
				t := t + 1;
		
		
			else
			
				case state is


					when PWR_UP =>
						jcpll.powerDown <= '1';		-- rising edge on power down
						state	:= IDLE;	

					
					when IDLE =>
						jcpll.SPI_latchEnable <= '1';
						jcpll.pllSync <= '1';
						i := 0;		-- data bit counter
						case dataSel is
							when 0 => data := x"01060320";
							when 1 => data := x"01060321";
							when 2 => data := x"01060302";
							when 3 => data := x"01060303";
							when 4 => data := x"01060314";
							when 5 => data := x"10101E75"; 
							when 6 => data := x"14AF0106";
							when 7 => data := x"BD99FDE7";
							when 8 => data := x"20009D98";
							when 9 => data := x"0000001F"; 	-- LOAD_PROM
							when others => null;
						end case;
						state := WRITE_DATA;
											
						
					when WRITE_DATA =>					
						jcpll.SPI_latchEnable <= '0';
						jcpll.SPI_MOSI <= data(i);
						i := i + 1;		-- number of serial data bits written
						if (i >= 32) then 
							dataSel := dataSel + 1;		-- number of data words written
							if (dataSel >= 10) then 
								i := 0;
								state := SYNC; 
							else 
								state := IDLE; 
							end if;
						else
							STATE	:= WRITE_DATA;
						end if;
		

					when SYNC =>
						jcpll.SPI_latchEnable <= '1';
						jcpll.pllSync <= '0';
						i := i + 1;
						if (i >= 32) then state	:= GND_STATE; end if;				

					
					when GND_STATE =>
						jcpll.SPI_latchEnable <= '1';
						jcpll.powerDown <= '1';
						jcpll.pllSync <= '1';

						
				end case;
			end if;
		end if;
		
	end process;	
	

	
end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

