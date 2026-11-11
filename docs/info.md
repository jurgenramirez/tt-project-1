<!---

This file is used to generate your project datasheet. Please fill in the information below and delete any unused
sections.

You can also include images in this folder and reference them in the markdown. Each image must be less than
512 kb in size, and the combined size of all images must be less than 1 MB.
-->

## How it works

Semáforo inteligente para el cruce de una calle principal (avenida con mucho tráfico) y una calle secundaria
(poco tráfico). La principal se queda en verde por defecto y solo cede el paso cuando un peatón presiona el
botón o un sensor detecta un carro en la secundaria. Así no se detiene la avenida cuando nadie espera.

Es una máquina de estados de Moore hecha con 5 flip-flops:

- **Contador de 4 bits (Q3..Q0):** indica la fase. Es un incrementador con habilitación: cada bit se
  invierte (XOR) cuando le llega el acarreo de los bits inferiores.
- **Bit de solicitud (`req`):** recuerda que alguien pidió paso, aunque haya soltado el botón. Se borra
  durante el cruce.

| Contador | Fase | Principal | Secundaria | Peatón |
|---|---|---|---|---|
| 0–6 | Verde principal | verde | rojo | rojo |
| 7 | Espera: se queda aquí mientras `req` = 0 | verde | rojo | rojo |
| 8–9 | Amarillo principal | amarillo | rojo | rojo |
| 10–14 | Cruce | rojo | verde | verde |
| 15 | Amarillo secundaria | rojo | amarillo | rojo |

La habilitación del contador es `EN = NAND(estado == 7, NOT req)`: solo vale 0 en el estado 7 sin
solicitud, y ahí el contador se detiene. Con un reloj de 1 Hz cada estado dura un segundo: al menos 8 s de
verde en la avenida, 2 s de amarillo, 5 s de cruce y 1 s de amarillo en la secundaria.

Las luces dependen solo del estado:

- Principal rojo = Q3·(Q2+Q1), principal amarillo = Q3·NOT(Q2+Q1), principal verde = NOT Q3
- Secundaria amarillo = Q3·Q2·Q1·Q0, secundaria verde = peatón verde = principal rojo · NOT secundaria amarillo
- Secundaria rojo = NOT principal rojo, peatón rojo = NOT peatón verde
- Siguiente `req` = (botón + sensor + `req`) · NOT principal rojo

## How to test

1. Configura el reloj del proyecto a 1 Hz (o avanza paso a paso con el reloj manual) y aplica un reset
   (`rst_n` en bajo).
2. Sin activar ninguna entrada, la calle principal debe quedarse en verde indefinidamente.
3. Activa un momento `ui[0]` (botón peatonal) o `ui[1]` (sensor de carro). Después de completar el verde
   mínimo, la principal pasa a amarillo (2 ciclos), luego hay cruce con la secundaria y el peatón en verde
   (5 ciclos), amarillo en la secundaria (1 ciclo) y vuelta al verde principal.
4. Si mantienes una entrada activa, el semáforo alterna continuamente entre la avenida y el cruce.

## External hardware

- 2 interruptores o botones en `ui[0]` (peatón) y `ui[1]` (sensor de carro), por ejemplo los DIP switch de la
  placa de Tiny Tapeout.
- 8 LEDs con resistencia en `uo[0]`–`uo[7]`: rojo, amarillo y verde de la principal; rojo, amarillo y verde de
  la secundaria; verde y rojo del peatón.
