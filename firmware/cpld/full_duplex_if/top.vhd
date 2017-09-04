--
-- Copyright 2016 Jared Boone
--
-- This file is part of HackRF.
--
-- This program is free software; you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation; either version 2, or (at your option)
-- any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program; see the file COPYING.  If not, write to
-- the Free Software Foundation, Inc., 51 Franklin Street,
-- Boston, MA 02110-1301, USA.

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity top is
	port (
		HOST_CLK           : in    std_logic;
		HOST_DATA          : inout std_logic_vector(7 downto 0);
		HOST_DIRECTION     : in    std_logic;
		HOST_FULL_DUPLEX_N : in    std_logic;
		HOST_ENABLE_N      : in    std_logic;
		HOST_CAPTURE_N     : out   std_logic;
		CODEC_CLK          : in    std_logic;
		CODEC_DA           : in    std_logic_vector(7 downto 0);
		CODEC_DD           : out   std_logic_vector(9 downto 0)
	);

end top;

architecture Behavioral of top is
	signal host_clk_i           : std_logic;
	signal codec_clk_i          : std_logic;
	
	signal host_direction_i     : std_logic;
	signal host_full_duplex_n_i : std_logic;
	signal host_enable_n_i      : std_logic;

	signal codec_da_i           : std_logic_vector(7 downto 0);
	signal host_data_rx_o       : std_logic_vector(7 downto 0);

	signal host_data_tx_i       : std_logic_vector(7 downto 0);
	signal codec_dd_o           : std_logic_vector(9 downto 0);    
	
	--------------------------------------------------------------------

	signal host_enable          : boolean;
	signal host_capture         : boolean;

	signal host_full_duplex     : boolean;
	signal host_half_duplex     : boolean;
	signal host_half_duplex_rx  : boolean;
	signal host_half_duplex_tx  : boolean;
	signal host_rx              : boolean;
	signal host_tx              : boolean;
	
	signal codec_clk_q1         : std_logic; 
	signal codec_clk_q2         : std_logic; 
	
	signal phase_2              : boolean;

	signal phase_even           : boolean;
	signal phase_odd            : boolean;

	signal enable_en            : boolean;
	signal enable_q0            : boolean;
	signal enable_q4            : boolean;
	signal enable_q8            : boolean;

	--------------------------------------------------------------------

	signal da_en                : boolean;
	signal da_q                 : std_logic_vector(7 downto 0);

	signal rx_h_en              : boolean;
	signal rx_l_en              : boolean;
	signal rx_l_mux_sel         : boolean;
	signal rx_h_q               : std_logic_vector(3 downto 0);
	signal rx_l_q               : std_logic_vector(3 downto 0);
	signal rx_h_oe              : boolean;
	signal rx_l_oe              : boolean;

	signal tx_l_en              : boolean;
	signal tx_h_en              : boolean;
	signal tx_h_q               : std_logic_vector(3 downto 0);
	signal tx_l_q               : std_logic_vector(3 downto 0);
	signal tx_fd_l_en           : boolean;
	signal tx_fd_h_en           : boolean;
	signal tx_fd_h_q            : std_logic_vector(3 downto 0);
	signal tx_fd_l_q            : std_logic_vector(3 downto 0);
	signal tx_fd_q              : std_logic_vector(7 downto 0);
	signal tx_hd_q              : std_logic_vector(7 downto 0);
	signal tx_mux_sel           : boolean;
	signal tx_mux               : std_logic_vector(7 downto 0);
	signal tx_2c                : std_logic_vector(7 downto 0);

	signal dd_en                : boolean;
	signal dd_q                 : std_logic_vector(7 downto 0);
begin
	-- MAX5864 voltage:code maps
	-- ADC in              ADC out             two's complement
	--  V * 127 / 128      1111 1111 (255)     0111 1111 (127)
	--  V *   1 / 128      1000 0001 (129)     0000 0001 (  1)
	--  V *   0 / 128      1000 0000 (128)     0000 0000 (  0)
	-- -V *   1 / 128      0111 1111 (127)     1111 1111 ( -1)
	-- -V * 128 / 128      0000 0000 (  0)     1000 0000 (-128)
	-- 
	-- two's complement    DAC in                  DAC out (dac_in * 2 - 1023)
	-- 0111 1111 ( 127)    11 1111 11xx (1020+o)    V * 1017 / 1023
	-- 0000 0001 (   1)    10 0000 01xx ( 516+o)    V *    7 / 1023
	-- 0000 0000 (   0)    10 0000 00xx ( 512+o)    V *    1 / 1023
	-- 1111 1111 (  -1)    01 1111 11xx ( 508+o)   -V *    3 / 1023
	-- 1000 0000 (-128)    00 0000 00xx (   0+o)   -V * 1023 / 1023
	--     dac_in = ((((twos_complement & 0xff) ^ 0x80) << 2) + o)
	--
	--              n where (Vrefdac / 2.56) * (n / 1023)
	--   DD[9:2]=     127       1       0      -1    -128
	-- DD[1:0]=00    1017       9       1      -7   -1023
	-- DD[1:0]=01    1019      11       3      -5   -1021
	-- DD[1:0]=10    1021      13       5      -3   -1019
	-- DD[1:0]=11    1023      15       7      -1   -1017

	-- Signals interfacing with the outside world.
	host_clk_i <= HOST_CLK;
	codec_clk_i <= CODEC_CLK;

	host_direction_i <= HOST_DIRECTION;
	host_full_duplex_n_i <= HOST_FULL_DUPLEX_N;
	host_enable_n_i <= HOST_ENABLE_N;
	HOST_CAPTURE_N <= '0' when host_capture else '1';

	codec_da_i <= CODEC_DA;
	CODEC_DD <= codec_dd_o;

	host_data_tx_i <= HOST_DATA;
	
	HOST_DATA <= host_data_rx_o;

	-- Helper signals
	host_enable <= (host_enable_n_i = '0');
	host_full_duplex <= (host_full_duplex_n_i = '0');
	host_half_duplex <= (host_full_duplex_n_i = '1');
	host_half_duplex_rx <= host_half_duplex and host_direction_i = '0';
	host_half_duplex_tx <= host_half_duplex and host_direction_i = '1';
	host_rx <= host_half_duplex_rx or host_full_duplex;
	host_tx <= host_half_duplex_tx or host_full_duplex;

	phase_2 <= codec_clk_q2 = '1' and codec_clk_q1 = '1';

	-- CODEC_CLK delays make a de facto two-bit gray code counter.
	process(host_clk_i)
	begin
		if rising_edge(host_clk_i) then
			codec_clk_q1 <= codec_clk_i;
			codec_clk_q2 <= codec_clk_q1;

			phase_even <= codec_clk_q1 /= codec_clk_q2;
			phase_odd <= codec_clk_q1 = codec_clk_q2;

			enable_en <= (host_half_duplex and codec_clk_q1 = '0') or (host_full_duplex and phase_2);
			da_en <= host_half_duplex or phase_even;
		end if;
	end process;

	host_capture <= enable_q4;

	process(host_clk_i)
	begin
		if rising_edge(host_clk_i) then
			if enable_en then
				enable_q0 <= host_enable;
				enable_q4 <= enable_q0;
				enable_q8 <= enable_q4;
			end if;
		end if;
	end process;

	rx_h_en <= true;
	rx_l_en <= true;
	rx_l_mux_sel <= host_full_duplex and phase_even;

	rx_h_oe <= host_half_duplex_rx;
	rx_l_oe <= host_rx;

	process(host_clk_i)
	begin
		if rising_edge(host_clk_i) then
			if da_en then
				da_q <= codec_da_i;
			end if;
		end if;    
	end process;

	process(host_clk_i)
	begin
		if rising_edge(host_clk_i) then
			if rx_h_en then
				rx_h_q <= da_q(7 downto 4) xor X"8";
			end if;
				
			if rx_l_en then
				if rx_l_mux_sel then
					rx_l_q <= rx_h_q;
				else
					rx_l_q <= da_q(3 downto 0);
				end if;
			end if;
		end if;
	end process;

	host_data_rx_o(7 downto 4) <= rx_h_q when rx_h_oe else (others => 'Z');
	host_data_rx_o(3 downto 0) <= rx_l_q when rx_l_oe else (others => 'Z');

	tx_l_en <= true;
	tx_h_en <= true;

	tx_fd_l_en <= phase_odd;
	tx_fd_h_en <= phase_even;

	tx_fd_q <= tx_fd_h_q & tx_fd_l_q;
	tx_hd_q <= tx_h_q & tx_l_q;

	tx_mux_sel <= host_full_duplex;
	tx_mux <= tx_fd_q when tx_mux_sel else tx_hd_q;
	tx_2c <= tx_mux xor X"80";

	dd_en <= host_half_duplex or phase_odd;

	process(host_clk_i)
	begin
		if rising_edge(host_clk_i) then
			if tx_l_en then
				tx_l_q <= host_data_tx_i(3 downto 0);
			end if;

			if tx_h_en then
				tx_h_q <= host_data_tx_i(7 downto 4);
			end if;

			if tx_fd_l_en then
				tx_fd_l_q <= tx_h_q;
			end if;
			
			if tx_fd_h_en then
				tx_fd_h_q <= tx_h_q;
			end if;
		end if;
	end process;

	process(host_clk_i, host_tx, host_enable)
	begin
		if not (host_tx and host_enable) then
			dd_q <= X"80";
		else
			if rising_edge(host_clk_i) then
				if dd_en then
					dd_q <= tx_2c;
				end if;
			end if;
		end if;
	end process;

	codec_dd_o <= dd_q & "00";

end Behavioral;
