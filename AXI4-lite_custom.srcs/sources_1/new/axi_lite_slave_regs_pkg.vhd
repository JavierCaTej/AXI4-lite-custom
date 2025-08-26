----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Javier Carmona Tejero
-- 
-- Create Date: 08/21/2025 08:04:55 PM
-- Design Name: 
-- Module Name: axi_lite_slave_regs_pkg - Behavioral
-- Project Name: 
-- Target Devices: 
-- Tool Versions: 
-- Description: 
-- 
-- Dependencies: 
-- 
-- Revision:
-- Revision 0.01 - File Created
-- Additional Comments:
-- 
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

package axi_lite_slave_regs_pkg is
  subtype reg32_t is std_logic_vector(31 downto 0);

  -- using decodification ADDR(7 downto 2)
  constant REG_CONTROL_IDX        : natural := 0; -- 0x00
  constant REG_STATUS_IDX         : natural := 1; -- 0x04
  constant REG_TIME_START_IDX     : natural := 2; -- 0x08
  constant REG_TIME_END_IDX       : natural := 3; -- 0x0C
  constant REG_RESULT_LATENCY_IDX : natural := 4; -- 0x10

  -- control and status 
  constant CTRL_START_BIT : natural := 0;  -- armar medicion
  constant CTRL_MEAS_SEL_BIT  : natural := 1;  -- 0=RESP, 1=RTT

  constant STAT_BUSY_BIT  : natural := 0;
  constant STAT_DONE_BIT  : natural := 1;
  constant STAT_ERR_BIT   : natural := 2;

  -- type register with the measurements
  type regs_t is record
    control        : reg32_t;
    status         : reg32_t;
    time_start     : reg32_t;
    time_end       : reg32_t;
    result_latency : reg32_t;
  end record;

  -- constant to reset a register
  constant REGS_RESET_C : regs_t;

  -- Helpers
  function wmask_from_wstrb(wstrb : std_logic_vector(3 downto 0)) return reg32_t;

  procedure write_reg_by_index(
    signal regs  : inout regs_t;
    index        : natural;
    wdata        : reg32_t;
    wstrb        : std_logic_vector(3 downto 0)
  );

  function read_reg_by_index(
    regs  : regs_t;
    index : natural
  ) return reg32_t;

  -- Atajos STATUS
  procedure status_set_bit(signal regs : inout regs_t; bitpos : natural);
  procedure status_clr_bit(signal regs : inout regs_t; bitpos : natural);

end package;

package body axi_lite_slave_regs_pkg is

  constant REGS_RESET_C : regs_t := (
    control        => (others => '0'),
    status         => (others => '0'),
    time_start     => (others => '0'),
    time_end       => (others => '0'),
    result_latency => (others => '0')
  );

  function wmask_from_wstrb(wstrb : std_logic_vector(3 downto 0)) return reg32_t is
    variable m : reg32_t := (others => '0');
  begin
    for i in 0 to 3 loop
      if wstrb(i) = '1' then
        m((8*i)+7 downto 8*i) := (others => '1');
      end if;
    end loop;
    return m;
  end function;

  procedure write_reg_by_index(
    signal regs  : inout regs_t;
    index        : natural;
    wdata        : reg32_t;
    wstrb        : std_logic_vector(3 downto 0)
  ) is
    variable tmp : regs_t;
    variable m : reg32_t := wmask_from_wstrb(wstrb);
  begin
    tmp := regs; -- copy status
    case index is
      when REG_CONTROL_IDX =>
        tmp.control := (tmp.control and (not m)) or (wdata and m);

      when REG_STATUS_IDX =>
        -- Ejemplo W1C: si quieres que escribir '1' borre bits de STATUS:
        -- tmp.status := tmp.status and (not (wdata and m));
        null; -- normalmente lo actualiza HW

      when REG_TIME_START_IDX =>
        tmp.time_start := (tmp.time_start and (not m)) or (wdata and m);

      when REG_TIME_END_IDX   =>
        tmp.time_end := (tmp.time_end and (not m)) or (wdata and m);

      when REG_RESULT_LATENCY_IDX =>
        tmp.result_latency := (tmp.result_latency and (not m)) or (wdata and m);

      when others => null;
    end case;
    regs <= tmp;
  end procedure;

  function read_reg_by_index(
    regs  : regs_t;
    index : natural
  ) return reg32_t is
  begin
    case index is
      when REG_CONTROL_IDX        => return regs.control;
      when REG_STATUS_IDX         => return regs.status;
      when REG_TIME_START_IDX     => return regs.time_start;
      when REG_TIME_END_IDX       => return regs.time_end;
      when REG_RESULT_LATENCY_IDX => return regs.result_latency;
      when others                 => return (others => '0');
    end case;
  end function;

  procedure status_set_bit(signal regs : inout regs_t; bitpos : natural) is
  begin
    regs.status(bitpos) <= '1';
  end procedure;

  procedure status_clr_bit(signal regs : inout regs_t; bitpos : natural) is
  begin
    regs.status(bitpos) <= '0';
  end procedure;

  procedure status_clear_done_err(signal regs : inout regs_t) is
  variable t : regs_t;
begin
  t := regs;
  t.status(STAT_DONE_BIT) := '0';
  t.status(STAT_ERR_BIT)  := '0';
  regs <= t;
end procedure;

procedure control_clear_start(signal regs : inout regs_t) is
  variable t : regs_t;
begin
  t := regs;
  t.control(CTRL_START_BIT) := '0';
  regs <= t;
end procedure;


end package body;

