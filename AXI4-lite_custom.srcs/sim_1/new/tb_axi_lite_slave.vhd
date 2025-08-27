-- =========================================================
-- Testbench para AXI4-Lite Slave
-- Archivo: tb_axi_lite_slave.vhd
-- Requiere:
--   - axi_lite_slave_regs_pkg.vhd (con índices/ayudas)
--   - axi_lite_slave_v1_0.vhd (tu DUT)
-- =========================================================
library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

use work.axi_lite_slave_regs_pkg.all;

entity tb_axi_lite_slave is
end entity;

architecture sim of tb_axi_lite_slave is

  -- =========================
  -- Señales AXI del TB
  -- =========================
  signal S_AXI_ACLK    : std_logic := '0';
  signal S_AXI_ARESETN : std_logic := '0';

  -- Write Address
  signal S_AXI_AWADDR  : std_logic_vector(31 downto 0) := (others => '0');
  signal S_AXI_AWVALID : std_logic := '0';
  signal S_AXI_AWREADY : std_logic;

  -- Write Data
  signal S_AXI_WDATA   : std_logic_vector(31 downto 0) := (others => '0');
  signal S_AXI_WSTRB   : std_logic_vector(3 downto 0)  := (others => '0');
  signal S_AXI_WVALID  : std_logic := '0';
  signal S_AXI_WREADY  : std_logic;

  -- Write Response
  signal S_AXI_BRESP   : std_logic_vector(1 downto 0);
  signal S_AXI_BVALID  : std_logic;
  signal S_AXI_BREADY  : std_logic := '0';

  -- Read Address
  signal S_AXI_ARADDR  : std_logic_vector(31 downto 0) := (others => '0');
  signal S_AXI_ARVALID : std_logic := '0';
  signal S_AXI_ARREADY : std_logic;

  -- Read Data
  signal S_AXI_RDATA   : std_logic_vector(31 downto 0);
  signal S_AXI_RRESP   : std_logic_vector(1 downto 0);
  signal S_AXI_RVALID  : std_logic;
  signal S_AXI_RREADY  : std_logic := '0';

  -- Otros
  constant CLK_PERIOD  : time := 10 ns; -- 100 MHz

  -- =========================
  -- Helpers del TB
  -- =========================

  -- Esperar N flancos de reloj
  procedure wait_clks(n : natural) is
  begin
    for i in 1 to n loop
      wait until rising_edge(S_AXI_ACLK);
    end loop;
  end procedure;

  -- Procedimiento de ESCRITURA AXI4-Lite
  procedure axi_write(
    signal ACLK    : in  std_logic;
    signal AWADDR  : out std_logic_vector(31 downto 0);
    signal AWVALID : out std_logic;
    signal AWREADY : in  std_logic;
    signal WDATA   : out std_logic_vector(31 downto 0);
    signal WSTRB   : out std_logic_vector(3 downto 0);
    signal WVALID  : out std_logic;
    signal WREADY  : in  std_logic;
    signal BRESP   : in  std_logic_vector(1 downto 0);
    signal BVALID  : in  std_logic;
    signal BREADY  : out std_logic;
    constant addr  : in  std_logic_vector(31 downto 0);
    constant data  : in  std_logic_vector(31 downto 0);
    constant c_wstrb : in  std_logic_vector(3 downto 0)
  ) is
  begin
    -- Coloca dirección y datos
    AWADDR  <= addr;
    WDATA   <= data;
    WSTRB   <= c_wstrb;
    AWVALID <= '1';
    WVALID  <= '1';
    BREADY  <= '1';

    -- Espera handshakes independientes (orden libre) y baja VALID
    wait until rising_edge(ACLK) and (AWREADY = '1');
    AWVALID <= '0';

    wait until rising_edge(ACLK) and (WREADY = '1');
    WVALID <= '0';

    -- Espera a la respuesta B
    wait until rising_edge(ACLK) and (BVALID = '1');
    assert BRESP = "00"
      report "BRESP != OKAY en axi_write"
      severity error;

    -- Baja BREADY y da un ciclo de reposo
    BREADY <= '0';
    wait until rising_edge(ACLK);
  end procedure;

  -- Procedimiento de LECTURA AXI4-Lite
  procedure axi_read(
    signal ACLK    : in  std_logic;
    signal ARADDR  : out std_logic_vector(31 downto 0);
    signal ARVALID : out std_logic;
    signal ARREADY : in  std_logic;
    signal RDATA   : in  std_logic_vector(31 downto 0);
    signal RRESP   : in  std_logic_vector(1 downto 0);
    signal RVALID  : in  std_logic;
    signal RREADY  : out std_logic;
    constant addr  : in  std_logic_vector(31 downto 0);
    variable data  : out std_logic_vector(31 downto 0)
  ) is
  begin
    -- Lanza dirección
    ARADDR  <= addr;
    ARVALID <= '1';
    RREADY  <= '1';

    -- Handshake AR y baja ARVALID
    wait until rising_edge(ACLK) and (ARREADY = '1');
    ARVALID <= '0';

    -- Espera dato
    wait until rising_edge(ACLK) and (RVALID = '1');
    assert RRESP = "00"
      report "RRESP != OKAY en axi_read"
      severity error;

    data := RDATA;

    -- Baja RREADY + 1 ciclo
    RREADY <= '0';
    wait until rising_edge(ACLK);
  end procedure;

  -- Buffer de lectura para prints/aserciones
  signal rd_data : std_logic_vector(31 downto 0);

begin
  -- =========================
  -- Reloj 100 MHz
  -- =========================
  clk_gen : process
  begin
    S_AXI_ACLK <= '0';
    wait for CLK_PERIOD/2;
    S_AXI_ACLK <= '1';
    wait for CLK_PERIOD/2;
  end process;

  -- =========================
  -- Instancia del DUT
  -- Ajusta el nombre de entidad si difiere
  -- =========================
  dut : entity work.axi_lite_slave
  port map (
    S_AXI_ACLK    => S_AXI_ACLK,
    S_AXI_ARESETN => S_AXI_ARESETN,

    S_AXI_AWADDR  => S_AXI_AWADDR,
    S_AXI_AWVALID => S_AXI_AWVALID,
    S_AXI_AWREADY => S_AXI_AWREADY,

    S_AXI_WDATA   => S_AXI_WDATA,
    S_AXI_WSTRB   => S_AXI_WSTRB,
    S_AXI_WVALID  => S_AXI_WVALID,
    S_AXI_WREADY  => S_AXI_WREADY,

    S_AXI_BRESP   => S_AXI_BRESP,
    S_AXI_BVALID  => S_AXI_BVALID,
    S_AXI_BREADY  => S_AXI_BREADY,

    S_AXI_ARADDR  => S_AXI_ARADDR,
    S_AXI_ARVALID => S_AXI_ARVALID,
    S_AXI_ARREADY => S_AXI_ARREADY,

    S_AXI_RDATA   => S_AXI_RDATA,
    S_AXI_RRESP   => S_AXI_RRESP,
    S_AXI_RVALID  => S_AXI_RVALID,
    S_AXI_RREADY  => S_AXI_RREADY
  );

  -- =========================
  -- Estímulos
  -- =========================
  stim : process
    variable tmp     : std_logic_vector(31 downto 0);
    variable t_start : std_logic_vector(31 downto 0);
    variable t_end   : std_logic_vector(31 downto 0);
    variable t_lat   : std_logic_vector(31 downto 0);
    function off(idx : natural) return std_logic_vector is
    begin
      -- offset = idx * 4 (ADDR[7:2] decode)
      return std_logic_vector(to_unsigned(idx, 32) sll 2);
    end function;
  begin
    -- Reset síncrono activo en bajo
    S_AXI_ARESETN <= '0';
    wait_clks(5);
    S_AXI_ARESETN <= '1';
    wait_clks(5);

    -- (1) Leer STATUS (0x04) tras reset
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_STATUS_IDX), tmp
    );
    report "STATUS (after reset) = " &
           integer'image(to_integer(unsigned(tmp)));

    -- (2) Escribir patrones de prueba en TIME_START/TIME_END/RESULT_LATENCY
    axi_write(
      S_AXI_ACLK, S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_AWREADY,
      S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WVALID, S_AXI_WREADY,
      S_AXI_BRESP, S_AXI_BVALID, S_AXI_BREADY,
      off(REG_TIME_START_IDX), x"11111111", "1111"
    );
    axi_write(
      S_AXI_ACLK, S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_AWREADY,
      S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WVALID, S_AXI_WREADY,
      S_AXI_BRESP, S_AXI_BVALID, S_AXI_BREADY,
      off(REG_TIME_END_IDX), x"22222222", "1111"
    );
    axi_write(
      S_AXI_ACLK, S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_AWREADY,
      S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WVALID, S_AXI_WREADY,
      S_AXI_BRESP, S_AXI_BVALID, S_AXI_BREADY,
      off(REG_RESULT_LATENCY_IDX), x"33333333", "1111"
    );

    -- (3) Leerlos y verificar que coinciden
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_TIME_START_IDX), tmp
    );
    assert tmp = x"11111111"
      report "TIME_START no retuvo el patrón escrito"
      severity error;
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_TIME_END_IDX), tmp
    );
    assert tmp = x"22222222"
      report "TIME_END no retuvo el patrón escrito"
      severity error;
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_RESULT_LATENCY_IDX), tmp
    );
    assert tmp = x"33333333"
      report "RESULT_LATENCY no retuvo el patrón escrito"
      severity error;

    -- (4) Escribir CONTROL=0x00000003 (START=bit0, MEAS_SEL=bit1)
    axi_write(
      S_AXI_ACLK, S_AXI_AWADDR, S_AXI_AWVALID, S_AXI_AWREADY,
      S_AXI_WDATA, S_AXI_WSTRB, S_AXI_WVALID, S_AXI_WREADY,
      S_AXI_BRESP, S_AXI_BVALID, S_AXI_BREADY,
      off(REG_CONTROL_IDX), x"00000003", "1111"
    );

    -- (5) Leer CONTROL y comprobar
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_CONTROL_IDX), tmp
    );
    report "CONTROL = " & integer'image(to_integer(unsigned(tmp)));
    assert tmp = x"00000003"
      report "CONTROL != 0x00000003 tras la escritura"
      severity error;

    -- (6) Esperar unos ciclos antes de iniciar la medición
    wait_clks(5);

    -- (7) Realizar una lectura para disparar la medición RTT
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_STATUS_IDX), tmp
    );

    -- (8) Leer TIME_START y TIME_END generados por el hardware
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_TIME_START_IDX), tmp
    );
    t_start := tmp;

    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_TIME_END_IDX), tmp
    );
    t_end := tmp;

    -- (9) Leer RESULT_LATENCY y comprobar coherencia
    axi_read(
      S_AXI_ACLK, S_AXI_ARADDR, S_AXI_ARVALID, S_AXI_ARREADY,
      S_AXI_RDATA, S_AXI_RRESP, S_AXI_RVALID, S_AXI_RREADY,
      off(REG_RESULT_LATENCY_IDX), tmp
    );
    t_lat := tmp;

    report "TIME_START = " & integer'image(to_integer(unsigned(t_start)));
    report "TIME_END   = " & integer'image(to_integer(unsigned(t_end)));
    report "LATENCY    = " & integer'image(to_integer(unsigned(t_lat)));

    assert unsigned(t_end) > unsigned(t_start)
      report "TIME_END no es mayor que TIME_START"
      severity error;
    assert unsigned(t_lat) = unsigned(t_end) - unsigned(t_start)
      report "RESULT_LATENCY != TIME_END - TIME_START"
      severity error;

    report "TB finalizado correctamente" severity note;
    wait_clks(10);
    -- Finaliza sim (si tu simulador soporta VHDL-2008 std.env.stop)
    -- std.env.stop;
    wait; -- fallback seguro
  end process;

end architecture;
