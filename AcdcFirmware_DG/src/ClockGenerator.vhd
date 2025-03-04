---------------------------------------------------------------------------------
-- Univ. of Chicago  
--    --KICP--
--
-- PROJECT:      ANNIE - ACDC
-- FILE:         clockGenerator.vhd
-- AUTHOR:       D. Greenshields
-- DATE:         July 2020
--
-- DESCRIPTION:  generates different clock frequencies for the firmware using
-- 					an on-board pll and also an external jitter cleaning pll
--
---------------------------------------------------------------------------------

library IEEE;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use work.components.all;
use work.defs.all;



entity ClockGenerator is
	Port(
		reset			:	in			std_logic;
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






	type STATE_TYPE is ( IDLE, PWR_UP, SERIALIZE, GND_STATE, CAL_HOLD, SYNC); 
-------------------------------------------------------------------------------
-- SIGNALS 
-------------------------------------------------------------------------------
	signal STATE          : STATE_TYPE;	
	signal DIN	  			: std_logic	:= '0';
	signal S_EN	  			: std_logic	:=	'0';
	signal PWR_DWN	  		: std_logic	:= '1';
	signal PLL_RST	  		: std_logic	:= '1';
	signal RAM_SEL			: std_logic_vector(3 downto 0) := x"F";
	signal xRAM				: std_logic_vector(31 downto 0);
	signal	serialClock	: std_logic;	
	signal	reset_z		: std_logic;
	signal	dacUpdate_z	: std_logic;
	signal	wilkUpdate_z	: std_logic;
	
begin




clock.usb <= clockIn.usb_IFCLK;



	
-- system clocks
PLL_MAP : pll port map
(

	inclk0	=>		clockIn.jcpll, 
	c0			=>		clock.sys, 		--	40MHz
	c1			=>		clock.uart,		-- 160MHz
	c2			=>		clock.trig,		-- 320MHz
	locked	=>		clock.altpllLock
);     
				




---------------------------------------
-- TIMER CLOCK GENERATOR
---------------------------------------
-- a general purpose 1ms clock for use in timers, delays, led flashers, timeouts etc. Not dependent on the jitter cleaner being set up
CLK_DIV_TIMER: process(clockIn.localOsc)
variable t: natural range 0 to 262143;
begin
	if (rising_edge(clockIn.localOsc)) then
		t := t + 1;
		if (t >= TIMER_CLK_DIV_RATIO) then t := 0; end if;
		if (t >= TIMER_CLK_DIV_RATIO /2) then clock.timer <= '1'; else clock.timer <= '0'; end if;
	end if;
end process;

	
	
	
	
	
	
	
	
	
---------------------------------------
-- DAC UPDATE CLOCK GENERATOR
---------------------------------------
DAC_CLK_GEN: process(clock.timer)
variable t: natural;
begin
	if (rising_edge(clock.timer)) then
		t := t + 1;
		if (t >= 100) then 	-- 100ms cycle time = 10Hz
			dacUpdate_z <= '1'; t := 0; 	
		else
			dacUpdate_z <= '0';
		end if;	
	end if;
end process;

-- synchronize the clock pulse to sys clock
DAC_CLK_SYNC: pulseSync port map (clock.timer, clock.sys, dacUpdate_z, clock.dacUpdate);
	
	
	
	
	
---------------------------------------
-- WILKINSON UPDATE CLOCK GENERATOR
---------------------------------------
WILK_CLK_GEN: process(clock.timer)
variable t: natural;
begin
	if (rising_edge(clock.timer)) then
		t := t + 1;
		if (t >= 100) then 	-- 100ms cycle time = 10Hz
			wilkUpdate_z <= '1'; t := 0; 	
		else
			wilkUpdate_z <= '0';
		end if;	
	end if;
end process;

-- synchronize the clock pulse to sys clock
WILK_CLK_SYNC: pulseSync port map (clock.timer, clock.sys, wilkUpdate_z, clock.wilkUpdate);
	
	
	
	
	
	
	
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

	jcpll.SPI_MOSI <= DIN;
	jcpll.SPI_latchEnable <= (not S_EN);
	jcpll.spi_clock <= serialClock;
	jcpll.powerDown <= (not PWR_DWN);
	jcpll.testMode <= '1';
	jcpll.pllSync <= (not PLL_RST);
	
	
	-- reference select
	-- 1 = Primary ref = lvds clock from ACC (normal operation)
	-- 0 = Secondary ref = on-board oscillator
	jcpll.refSelect <= '1';			


	process(RAM_SEL)
	begin
		case RAM_SEL is
			when x"0" => xRAM <= x"01060320";
			when x"1" => xRAM <= x"01060321";
			when x"2" => xRAM <= x"01060302";
			when x"3" => xRAM <= x"01060303";
			when x"4" => xRAM <= x"01060314";
			when x"5" => xRAM <= x"10101E75";	-- For 25MHz => x"10001E75";	For 125MHz => x"10101E75";
			when x"6" => xRAM <= x"14AF0106";
			when x"7" => xRAM <= x"BD99FDE7";
			when x"8" => xRAM <= x"20009D98";
			when x"9" => xRAM <= x"0000001F"; 	-- LOAD_PROM
			when others =>	xRAM <= x"00000000";
		end case;
	end process;

-------------------------------------------------------------------------------

	process(serialClock)
	variable i	: natural;
	variable t: natural := 0;
	begin
		if (falling_edge(serialClock)) then
		
		
			
		
			if (t < 40000) then 
			
				DIN 		<= '0';
				S_EN 		<= '0';
				PWR_DWN 	<= '1';
				PLL_RST 	<= '1';
				RAM_SEL <= x"F";
				STATE	<= PWR_UP;		
				t := t + 1;	
				
		
			else
			
				case STATE is


					when PWR_UP =>
						PWR_DWN 	<= '1';
						PLL_RST 	<= '1';
						STATE	<= CAL_HOLD;	

					
					when CAL_HOLD =>
						PWR_DWN 	<= '0';
						PLL_RST 	<= '1';
						STATE	<= IDLE;	

					
					when IDLE =>
						DIN 		<= '0';
						S_EN 		<= '0';
						PWR_DWN 	<= '0';
						PLL_RST 	<= '0';
						i := 0;
						if RAM_SEL = x"9" then
							RAM_SEL <= x"F";
							STATE	<= SYNC;
						else
							RAM_SEL <= RAM_SEL + 1;
							STATE	<= SERIALIZE;
						end if;

					
					when SERIALIZE =>
						S_EN 	<= '1';
						DIN 	<= xRAM(i);
						if i = 31 then
							STATE	<= IDLE;
						else
							i := i + 1;
						end if;

					
					when SYNC =>
						PLL_RST 	<= '1';
						if i = 31 then
							STATE	<= GND_STATE;
						else
							i := i + 1;
						end if;				

					
					when GND_STATE =>
						DIN 		<= '0';
						S_EN 		<= '0';
						PWR_DWN 	<= '0';
						PLL_RST 	<= '0';
						RAM_SEL <= x"F";

						
				end case;
			end if;
		end if;
		
	end process;	
	

	
end vhdl;

		
	
	
	
	
	
	
	
	
	
	
	
	
	
	

