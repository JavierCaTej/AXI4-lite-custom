----------------------------------------------------------------------------------
-- Company: 
-- Engineer: Javier Carmona Tejero
-- 
-- Create Date: 08/21/2025 08:04:55 PM
-- Design Name: 
-- Module Name: axi_lite_slave_v1_0 - Behavioral
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
use IEEE.STD_LOGIC_1164.all;
use IEEE.NUMERIC_STD.ALL;
use work.axi_lite_slave_regs_pkg.all;

--library UNISIM;
--use UNISIM.VComponents.all;

entity axi_lite_slave is
  port (
    -- Clock and Reset
    S_AXI_ACLK    : in std_logic;
    S_AXI_ARESETN : in std_logic;

    -- Write Address Channel
    S_AXI_AWADDR  : in std_logic_vector(31 downto 0);
    S_AXI_AWVALID : in std_logic;
    S_AXI_AWREADY : out std_logic;

    -- Write Data Channel
    S_AXI_WDATA  : in std_logic_vector(31 downto 0);
    S_AXI_WSTRB  : in std_logic_vector(3 downto 0); -- habilitar 1 byte -- 2^6 = 64 registers -- each register jump 4 (32 bits = 4 bytes) address 0x0 0x4 0x8 0xC 0x10
    S_AXI_WVALID : in std_logic;
    S_AXI_WREADY : out std_logic;

    -- Write Response Channel
    S_AXI_BRESP  : out std_logic_vector(1 downto 0);
    S_AXI_BVALID : out std_logic;
    S_AXI_BREADY : in std_logic;

    -- Read Address Channel
    S_AXI_ARADDR  : in std_logic_vector(31 downto 0);
    S_AXI_ARVALID : in std_logic;
    S_AXI_ARREADY : out std_logic;

    -- Read Data Channel
    S_AXI_RDATA  : out std_logic_vector(31 downto 0);
    S_AXI_RRESP  : out std_logic_vector(1 downto 0);
    S_AXI_RVALID : out std_logic;
    S_AXI_RREADY : in std_logic

  );
end axi_lite_slave;

architecture Behavioral of axi_lite_slave is

signal regs     : regs_t := REGS_RESET_C;

----------------------------
-- Señales internas
----------------------------
signal awready_i : std_logic;
signal wready_i  : std_logic;
signal arready_i : std_logic;
signal bvalid_i  : std_logic;
signal rvalid_i  : std_logic;

signal aw_hs     : std_logic; -- AW handshake (aceptada dir de escritura)
signal w_hs      : std_logic; -- W  handshake (aceptado dato de escritura)
signal b_busy    : std_logic; -- hay respuesta B pendiente
signal ar_hs     : std_logic; -- AR handshake (aceptada dir de lectura)
signal r_busy    : std_logic; -- hay dato R pendiente

signal aw_index : unsigned(5 downto 0); -- Indice registro escritura
signal ar_index : unsigned(5 downto 0); -- Indice registro lectura

-- Latches (registros de captura)
signal awaddr_lat  : std_logic_vector(31 downto 0);
signal wdata_lat   : std_logic_vector(31 downto 0);
signal wstrb_lat   : std_logic_vector(3 downto 0);
signal araddr_lat  : std_logic_vector(31 downto 0);

-- Flags de captura
signal have_aw : std_logic;
signal have_w  : std_logic;

-- Índices ya a partir del latch
signal aw_index_lat : unsigned(5 downto 0);
signal ar_index_lat : unsigned(5 downto 0);

----------------------------
-- Señales medicion
----------------------------
-- Contador libre para timestamp
constant COUNTER_WIDTH : natural := 32;
signal cyc_cnt : unsigned (COUNTER_WIDTH-1 downto 0);

-- Estado de medición
signal armed       : std_logic := '0';  -- armado tras CONTROL.START
signal measure_rtt : std_logic := '0';  -- 0=RESP, 1=RTT

-- Señal interna para saber si la escritura actual es al registro CONTROL
signal is_control_write : std_logic;
signal measuring_write : std_logic := '0'; -- 1 si se mide una escritura

begin
-- ===========================
-- 1. LOGIC
-- ===========================
-- Asignación de las señales internas a los puertos
S_AXI_AWREADY <= awready_i;
S_AXI_WREADY  <= wready_i;
S_AXI_ARREADY <= arready_i;
S_AXI_BVALID  <= bvalid_i;
S_AXI_RVALID  <= rvalid_i;

-- Decodificacion del indice
aw_index <= unsigned(S_AXI_AWADDR(7 downto 2));
ar_index <= unsigned(S_AXI_ARADDR(7 downto 2));

-- Handshakes combinacionales
aw_hs <= S_AXI_AWVALID and awready_i;
w_hs  <= S_AXI_WVALID  and wready_i;
ar_hs <= S_AXI_ARVALID and arready_i;

is_control_write <= '1' when aw_index_lat = REG_CONTROL_IDX else '0';

-- ===========================
-- 2. PROCESS
-- ===========================

-- ===========================
-- Canal de ESCRITURA (AW/W/B)
-- Política simple: aceptar siempre AW y W; emitir B cuando se reciban ambos.
-- ===========================
write_ctrl : process(S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then
    if S_AXI_ARESETN = '0' then
      awready_i <= '0';
      wready_i  <= '0';
      bvalid_i  <= '0';
      S_AXI_BRESP   <= "00";
      b_busy        <= '0';
      have_aw     <= '0';
      have_w      <= '0';
      awaddr_lat  <= (others => '0');
      wdata_lat   <= (others => '0');
      wstrb_lat   <= (others => '0');
      armed        <= '0';
      measure_rtt  <= '0';
      measuring_write <= '0';
    else
      -- Back-pressure: si hay B pendiente, no aceptar más nada
      awready_i <= (not b_busy) and (not have_aw);
      wready_i  <= (not b_busy) and (not have_w);

      -- Captura AW (latch)
      if aw_hs = '1' then
        awaddr_lat <= S_AXI_AWADDR;
        aw_index_lat <= aw_index;
        have_aw    <= '1';
      end if;

      -- Captura W (latch)
      if w_hs = '1' then
        wdata_lat <= S_AXI_WDATA;
        wstrb_lat <= S_AXI_WSTRB;
        have_w    <= '1';
      end if;

      -- Cuando tengo ambos, actualizo registro y genero B
      if (have_aw = '1' and have_w = '1' and b_busy = '0') then
        -- ESCRITURA REAL (helper de tu package):
        write_reg_by_index(regs, to_integer(aw_index_lat), wdata_lat, wstrb_lat);
        if is_control_write = '1' then
          if (wstrb_lat(0) = '1' and wdata_lat(CTRL_START_BIT) = '1') then
            armed       <= '1';
            measure_rtt <= wdata_lat(CTRL_MODE_BIT);
            status_clear_done_err(regs);
          end if;
        elsif armed = '1' then
          regs.time_start <= std_logic_vector(cyc_cnt);
          status_set_bit(regs, STAT_BUSY_BIT);
          measuring_write <= '1';
        end if;

        S_AXI_BRESP  <= "00";      -- OKAY
        bvalid_i     <= '1';
        b_busy       <= '1';

        -- Finalizar medición en modo RESP
        if (armed = '1' and measuring_write = '1' and measure_rtt = '0') then
          regs.time_end       <= std_logic_vector(cyc_cnt);
          regs.result_latency <= std_logic_vector(cyc_cnt - unsigned(regs.time_start));
          status_clr_bit(regs, STAT_BUSY_BIT);
          status_set_bit(regs, STAT_DONE_BIT);
          control_clear_start(regs);
          armed           <= '0';
          measuring_write <= '0';
        end if;

        -- Libero los latches para aceptar la siguiente
        have_aw <= '0';
        have_w  <= '0';
      end if;

      -- Completar canal B
      if (bvalid_i = '1' and S_AXI_BREADY = '1') then
        if (armed = '1' and measuring_write = '1' and measure_rtt = '1') then
          regs.time_end       <= std_logic_vector(cyc_cnt);
          regs.result_latency <= std_logic_vector(cyc_cnt - unsigned(regs.time_start));
          status_clr_bit(regs, STAT_BUSY_BIT);
          status_set_bit(regs, STAT_DONE_BIT);
          control_clear_start(regs);
          armed           <= '0';
          measuring_write <= '0';
        end if;
        bvalid_i     <= '0';
        b_busy       <= '0';
      end if;
    end if;
  end if;
end process;

-- =========================
-- Canal de LECTURA (AR/R)
-- Política simple: aceptar siempre AR; presentar dato 1 ciclo después y esperar RREADY.
-- =========================
read_ctrl : process(S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then
    if S_AXI_ARESETN = '0' then
      arready_i <= '0';
      rvalid_i  <= '0';
      S_AXI_RRESP   <= "00";
      r_busy        <= '0';
      S_AXI_RDATA   <= (others => '0');
      araddr_lat  <= (others => '0');
      armed        <= '0';
      measure_rtt  <= '0';
      measuring_write <= '0';
    else
      -- No aceptar otra AR si hay R pendiente
      arready_i <= (not r_busy);

      -- Cuando aceptamos la dirección de lectura, preparar dato y marcar pendiente
      if ar_hs = '1' then
        -- latch de la dirección
        araddr_lat   <= S_AXI_ARADDR;
        ar_index_lat <= ar_index;

        -- LECTURA DE REGISTRO:
        S_AXI_RDATA <= read_reg_by_index(regs, to_integer(ar_index));

        S_AXI_RRESP  <= "00"; -- OKAY
        rvalid_i <= '1';
        r_busy       <= '1';

        if armed = '1' then
          regs.time_start <= std_logic_vector(cyc_cnt);
          status_set_bit(regs, STAT_BUSY_BIT);
          measuring_write <= '0';
        end if;
      end if;

      if (armed = '1' and measuring_write = '0' and measure_rtt = '0' and rvalid_i = '1') then
        regs.time_end       <= std_logic_vector(cyc_cnt);
        regs.result_latency <= std_logic_vector(cyc_cnt - unsigned(regs.time_start));
        status_clr_bit(regs, STAT_BUSY_BIT);
        status_set_bit(regs, STAT_DONE_BIT);
        control_clear_start(regs);
        armed <= '0';
      end if;

      -- Completar canal R
      if (rvalid_i = '1' and S_AXI_RREADY = '1') then
        if (armed = '1' and measuring_write = '0' and measure_rtt = '1') then
          regs.time_end       <= std_logic_vector(cyc_cnt);
          regs.result_latency <= std_logic_vector(cyc_cnt - unsigned(regs.time_start));
          status_clr_bit(regs, STAT_BUSY_BIT);
          status_set_bit(regs, STAT_DONE_BIT);
          control_clear_start(regs);
          armed <= '0';
        end if;
        rvalid_i <= '0';
        r_busy       <= '0';
      end if;
    end if;
  end if;
end process;

-- =========================
-- Cycles counter
-- =========================
process(S_AXI_ACLK)
begin
  if rising_edge(S_AXI_ACLK) then
    if S_AXI_ARESETN='0' then
      cyc_cnt <= (others=>'0');
    else
      cyc_cnt <= cyc_cnt + 1;
    end if;
  end if;
end process;




end Behavioral;