/*
 * Semáforo inteligente
 * Copyright (c) 2026 Jurgen Ramirez
 * SPDX-License-Identifier: Apache-2.0
 *
 * Traducción directa del diagrama de Wokwi: cada señal lleva el mismo id que
 * la compuerta o flip-flop del diagram.json (a1, en, x0, mr, ff_q0, ...).
 *
 * Analogía de programación:
 *   - Los "reg" (flip-flops) son variables que solo cambian en el flanco de
 *     subida del reloj, todas a la vez (asignación simultánea al final del ciclo).
 *   - Los "assign" son expresiones booleanas que se evalúan en paralelo,
 *     todo el tiempo, como compuertas conectadas con cables.
 *
 * Un estado por ciclo de reloj (en Wokwi: reloj de 1 Hz = un estado por segundo).
 *
 *   Contador  Fase                 Principal  Secundaria  Peatón
 *   0-6       Verde principal      verde      rojo        rojo
 *   7         Espera (si req=0)    verde      rojo        rojo
 *   8-9       Amarillo principal   amarillo   rojo        rojo
 *   10-14     Cruce                rojo       verde       verde
 *   15        Amarillo secundaria  rojo       amarillo    rojo
 */

`default_nettype none

module tt_um_jurgenramirez_semaforo (
    input  wire [7:0] ui_in,    // Entradas dedicadas
    output wire [7:0] uo_out,   // Salidas dedicadas
    input  wire [7:0] uio_in,   // Bidireccionales: entrada (sin usar)
    output wire [7:0] uio_out,  // Bidireccionales: salida (sin usar)
    output wire [7:0] uio_oe,   // Bidireccionales: habilitación (0 = entrada)
    input  wire       ena,      // Siempre 1 cuando el diseño está activo
    input  wire       clk,      // Reloj: un estado por flanco de subida
    input  wire       rst_n     // Reset activo en bajo
);

  // ---------------- Entradas ----------------
  wire in0 = ui_in[0];  // DIP 1: botón peatonal
  wire in1 = ui_in[1];  // DIP 2: sensor de carro en la calle secundaria

  // nrst: NOT del reset; va a la entrada R de todos los flip-flops
  wire nrst = ~rst_n;

  // ---------------- Flip-flops (estado) ----------------
  // ff_q0..ff_q3: contador de 4 bits Q3..Q0.  ff_req: hay alguien esperando.
  reg q0, q1, q2, q3, req;
  wire d0, d1, d2, d3, d_req;

  // Igual que wokwi-flip-flop-dr: reset asíncrono activo en alto (R).
  always @(posedge clk or posedge nrst) begin
    if (nrst) begin
      q0  <= 1'b0;
      q1  <= 1'b0;
      q2  <= 1'b0;
      q3  <= 1'b0;
      req <= 1'b0;
    end else begin
      q0  <= d0;
      q1  <= d1;
      q2  <= d2;
      q3  <= d3;
      req <= d_req;
    end
  end

  // ---------------- Lógica de transición ----------------
  // Detectar el estado 7 (0111)
  wire a1  = q0 & q1;         // a1
  wire a2  = a1 & q2;         // a2
  wire at7 = a2 & ~q3;        // at7 (usa NOTQ de ff_q3)

  // EN = 0 solo en el estado 7 sin solicitud: el contador se detiene ahí
  wire en  = ~(at7 & ~req);   // en (NAND, usa NOTQ de ff_req)

  // Incrementador con habilitación: acarreos
  wire c1 = en & q0;          // c1
  wire c2 = c1 & q1;          // c2
  wire c3 = c2 & q2;          // c3

  // Siguiente estado: cada bit cambia si le llega acarreo
  assign d0 = q0 ^ en;        // x0
  assign d1 = q1 ^ c1;        // x1
  assign d2 = q2 ^ c2;        // x2
  assign d3 = q3 ^ c3;        // x3

  // ---------------- Luces (Moore: dependen solo del estado) ----------------
  wire q21  = q2 | q1;        // q21
  wire mr   = q3 & q21;       // mr:   principal rojo (estados 10-15)
  wire nq21 = ~q21;           // nq21
  wire my   = q3 & nq21;      // my:   principal amarillo (estados 8-9)
  wire sy   = a2 & q3;        // sy:   secundaria amarillo (estado 15)
  wire nsy  = ~sy;            // nsy
  wire sg   = mr & nsy;       // sg:   secundaria verde = peatón verde (10-14)
  wire nmr  = ~mr;            // nmr:  secundaria rojo (estados 0-9)
  wire nsg  = ~sg;            // nsg:  peatón rojo

  // ---------------- Memoria de solicitud ----------------
  // Se activa con el botón o el sensor, se mantiene, y se borra en el cruce.
  wire o1 = in0 | in1;        // o1
  wire o2 = o1 | req;         // o2
  assign d_req = o2 & nmr;    // dreq

  // ---------------- Salidas ----------------
  assign uo_out[0] = mr;      // Principal rojo
  assign uo_out[1] = my;      // Principal amarillo
  assign uo_out[2] = ~q3;     // Principal verde (NOTQ de ff_q3)
  assign uo_out[3] = nmr;     // Secundaria rojo
  assign uo_out[4] = sy;      // Secundaria amarillo
  assign uo_out[5] = sg;      // Secundaria verde
  assign uo_out[6] = sg;      // Peatón verde
  assign uo_out[7] = nsg;     // Peatón rojo

  // Pines bidireccionales sin usar: todos como entrada
  assign uio_out = 8'b0;
  assign uio_oe  = 8'b0;

  // Evitar advertencias por entradas sin usar
  wire _unused = &{ena, ui_in[7:2], uio_in, 1'b0};

endmodule
