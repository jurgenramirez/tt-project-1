# SPDX-License-Identifier: Apache-2.0
# Pruebas del semáforo inteligente. Solo usan los pines del chip (ui_in/uo_out),
# así que funcionan igual en simulación RTL y en la de compuertas (GATES=yes).

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge

# uo_out: [0] P rojo, [1] P amarillo, [2] P verde,
#         [3] S rojo, [4] S amarillo, [5] S verde,
#         [6] peatón verde, [7] peatón rojo
VERDE_PRINCIPAL = "VRR"  # principal verde, secundaria rojo, peatón rojo
AMARILLO_PRINCIPAL = "ARR"
CRUCE = "RVV"            # principal rojo, secundaria verde, peatón verde
AMARILLO_SECUNDARIA = "RAR"

BOTON = 0b01   # ui_in[0]
SENSOR = 0b10  # ui_in[1]


def luces(dut):
    """Devuelve las luces como texto de 3 letras y verifica que sean coherentes."""
    o = int(dut.uo_out.value)
    b = [(o >> i) & 1 for i in range(8)]
    assert sum(b[0:3]) == 1, f"Principal con {sum(b[0:3])} luces encendidas: {o:08b}"
    assert sum(b[3:6]) == 1, f"Secundaria con {sum(b[3:6])} luces encendidas: {o:08b}"
    assert b[6] + b[7] == 1, f"Peatón con {b[6] + b[7]} luces encendidas: {o:08b}"
    p = "R" if b[0] else "A" if b[1] else "V"
    s = "R" if b[3] else "A" if b[4] else "V"
    w = "V" if b[6] else "R"
    return p + s + w


async def iniciar(dut):
    cocotb.start_soon(Clock(dut.clk, 10, unit="us").start())
    dut.ena.value = 1
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.rst_n.value = 0
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1


async def siguiente(dut):
    """Avanza un ciclo y lee las luces a mitad de ciclo (cuando ya son estables)."""
    await FallingEdge(dut.clk)
    return luces(dut)


async def esperar_fase(dut, fase, max_ciclos=40):
    for _ in range(max_ciclos):
        if luces(dut) == fase:
            return
        await siguiente(dut)
    assert False, f"No se llegó a la fase {fase}"


async def verificar_ciclo_completo(dut):
    """Desde el fin de la espera: 2 amarillo, 5 cruce, 1 amarillo secundaria, vuelve a verde."""
    esperado = [AMARILLO_PRINCIPAL] * 2 + [CRUCE] * 5 + [AMARILLO_SECUNDARIA] + [VERDE_PRINCIPAL]
    obtenido = [luces(dut)]
    for _ in range(len(esperado) - 1):
        obtenido.append(await siguiente(dut))
    assert obtenido == esperado, f"Secuencia {obtenido}, se esperaba {esperado}"


@cocotb.test()
async def test_reset_y_espera(dut):
    """Sin nadie esperando, la principal se queda en verde indefinidamente."""
    await iniciar(dut)
    assert luces(dut) == VERDE_PRINCIPAL, "Después del reset debe estar en verde principal"
    for _ in range(50):
        assert await siguiente(dut) == VERDE_PRINCIPAL, "La avenida no debe detenerse si nadie espera"


@cocotb.test()
async def test_boton_peatonal(dut):
    """Un pulso del botón queda guardado y produce un ciclo completo de cruce."""
    await iniciar(dut)
    await ClockCycles(dut.clk, 20)  # ya está detenido en el estado 7
    await FallingEdge(dut.clk)
    dut.ui_in.value = BOTON
    await FallingEdge(dut.clk)      # el flip-flop req captura el pulso
    dut.ui_in.value = 0
    assert luces(dut) == VERDE_PRINCIPAL
    await siguiente(dut)            # con req=1 el contador sale del estado 7
    await verificar_ciclo_completo(dut)
    # La solicitud se borró en el cruce: vuelve a quedarse en verde
    for _ in range(30):
        assert await siguiente(dut) == VERDE_PRINCIPAL


@cocotb.test()
async def test_sensor_de_carro(dut):
    """El sensor de la calle secundaria también abre el cruce."""
    await iniciar(dut)
    await ClockCycles(dut.clk, 15)
    await FallingEdge(dut.clk)
    dut.ui_in.value = SENSOR
    await esperar_fase(dut, AMARILLO_PRINCIPAL)
    dut.ui_in.value = 0
    await verificar_ciclo_completo(dut)


@cocotb.test()
async def test_verde_minimo(dut):
    """Si se pide paso justo después del reset, la principal igual da 8 ciclos de verde."""
    await iniciar(dut)
    dut.ui_in.value = BOTON
    verdes = 1
    while await siguiente(dut) == VERDE_PRINCIPAL:
        verdes += 1
    dut.ui_in.value = 0
    assert verdes == 8, f"Verde principal duró {verdes} ciclos, se esperaban 8 (estados 0-7)"


@cocotb.test()
async def test_solicitud_constante(dut):
    """Con el botón siempre presionado el semáforo alterna sin quedarse trabado."""
    await iniciar(dut)
    dut.ui_in.value = BOTON | SENSOR
    for _ in range(3):
        await esperar_fase(dut, AMARILLO_PRINCIPAL)
        await verificar_ciclo_completo(dut)
