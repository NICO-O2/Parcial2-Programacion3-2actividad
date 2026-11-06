# README HECHO POR LA IA (IA utilizada Claude Code Sonnet 5.5)

# Parcial 2 - Programación III (Elixir) - Problema 1: Robot de rescate

Robot que va de S a M con energía limitada B, sin repetir casillas. Encuentra todos los recorridos simples, los de menos movimientos y los de menor energía, y dibuja la ruta óptima en un SVG.

Requisitos: Elixir instalado. `Util.ex` y `Util2.ex` deben estar en la misma carpeta que `rescate.exs`.

## Cómo ejecutar (desde esta carpeta)

    elixir rescate.exs

Lee `entrada/rescate` y escribe en `salida/rescate`. También se puede indicar la carpeta de entrada y la de salida:

    elixir rescate.exs pruebas/rescate/invalido salida/pruebas/rescate_invalido

## Archivos de entrada (en la carpeta de entrada)
- `edificio.txt`: matriz de símbolos separados por espacios.
- `terrenos.csv`: `simbolo,nombre,transitable,costo`.
- `bateria.txt`: entero positivo B.

## Archivos de salida (en la carpeta de salida)
- `validacion_edificio.txt`: errores de la entrada (si hay errores no se inicia la búsqueda).
- `expansion_energia.txt`: pasos del Stream infinito de relajación y el índice de estabilización.
- `recorridos_rescate.csv`: `id;movimientos;energia;posiciones`.
- `resumen_rescate.txt`: total, recorridos con menos movimientos y con menor energía (también se muestra en pantalla).
- `ruta_optima.svg`: edificio con casillas de 40 x 40 y la ruta de menor energía.

## Casos de prueba (carpeta `pruebas/rescate/`) y resultado esperado
- `entrada/rescate` (ejemplo del enunciado, B=10): 6 recorridos; menos movimientos = recorrido 1 (3 mov.); menor energía = recorrido 1 (5). La relajación se estabiliza en el índice 5.
- `criterios_distintos` (válido, B=10): 7 recorridos; menos movimientos = recorrido 1 (3 mov., energía 7); menor energía = recorrido 7 (5).
- `limite_minimo` (S junto a M, B=1): 1 recorrido de 1 movimiento y energía 1.
- `limite_sin_ruta` (ejemplo con B=4): la meta no es alcanzable; no se enumera, 0 recorridos y el SVG dice «sin recorrido».
- `invalido`: filas de distinto largo, símbolo no definido, dos S, borde sin X, símbolo repetido, costo 0 en terreno transitable, registro mal formado y B no numérico. Solo se genera `validacion_edificio.txt`.

## Notas
- En `recorridos_rescate.csv`, `movimientos` es la cantidad de movimientos y `posiciones` las coordenadas {fila, columna} (origen en 0) separadas con ` -> `.
- El orden de los movimientos es: arriba, derecha, abajo, izquierda. En un empate de energía, el SVG dibuja el primer recorrido encontrado en ese orden.

## Autores
Eric Santiago Correa Alzate
Nicolay Ramirez Ramirez
Juan Jose Marin Carmona
