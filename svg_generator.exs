defmodule SVGGenerator do
  def generar_vacio do
    Util.con_archivo("mejor_plan.svg", fn file ->
      Util.escribir_linea(file, """
      <svg xmlns="http://www.w3.org/2000/svg" width="500" height="150" viewBox="0 0 500 150">
        <rect width="100%" height="100%" fill="#f9f9f9"/>
        <text x="250" y="75" dominant-baseline="middle" text-anchor="middle" font-family="sans-serif" font-size="16" fill="#666">
          Proyecto vacío: No hay tareas para diagramar.
        </text>
      </svg>
      """)
    end)
  end

  def generar(nil, _mapa), do: generar_vacio()
  def generar(%Plan{} = plan, mapa_tareas) do
    Util.con_archivo("mejor_plan.svg", fn file ->
      ancho_lbl = 80
      alto_fila = 40
      margen_sup = 60
      margen_inf = 50
      px_por_unidad = 40

      total_tiempo = plan.duracion_total
      ancho_total = ancho_lbl + max(total_tiempo * px_por_unidad, 300) + 60
      alto_total = margen_sup + (length(plan.orden) * alto_fila) + margen_inf

      Util.escribir_linea(file, ~s|<svg xmlns="http://www.w3.org/2000/svg" width="#{ancho_total}" height="#{alto_total}">|)
      dibujar_estilos(file)
      dibujar_encabezado(file, plan.penalizacion)
      dibujar_grid(file, total_tiempo, ancho_lbl, px_por_unidad, margen_sup, alto_total, margen_inf)
      dibujar_barras(file, plan, mapa_tareas, ancho_lbl, px_por_unidad, margen_sup, alto_fila)
      dibujar_leyenda(file, ancho_lbl, alto_total)
      Util.escribir_linea(file, "</svg>")
    end)
  end

  defp dibujar_estilos(file) do
    Util.escribir_linea(file, """
      <style>
        .label { font-family: Arial, sans-serif; font-size: 14px; font-weight: bold; fill: #333; }
        .grid { stroke: #e0e0e0; stroke-width: 1; stroke-dasharray: 4,4; }
        .axis { stroke: #333; stroke-width: 2; }
        .bar-ok { fill: #4CAF50; rx: 4; ry: 4; }
        .bar-late { fill: #E53935; rx: 4; ry: 4; }
        .text-time { font-family: Arial, sans-serif; font-size: 11px; fill: #ffffff; font-weight: bold; }
        .text-axis { font-family: Arial, sans-serif; font-size: 12px; fill: #555; }
        .title { font-family: Arial, sans-serif; font-size: 16px; font-weight: bold; fill: #111; }
      </style>
    """)
  end

  defp dibujar_encabezado(file, penalizacion) do
    Util.escribir_linea(file, ~s|  <rect width="100%" height="100%" fill="#ffffff" />|)
    Util.escribir_linea(file, ~s|  <text x="20" y="30" class="title">Diagrama de Gantt - Primer Plan Óptimo (Penalización: #{penalizacion})</text>|)
  end

  defp dibujar_grid(file, total_tiempo, ancho_lbl, px, margen_sup, alto_total, margen_inf) do
    0..total_tiempo
    |> Enum.each(fn t ->
      x = ancho_lbl + t * px
      y1 = margen_sup - 10
      y2 = alto_total - margen_inf + 10
      Util.escribir_linea(file, ~s|  <line x1="#{x}" y1="#{y1}" x2="#{x}" y2="#{y2}" class="grid" />|)
      Util.escribir_linea(file, ~s|  <text x="#{x}" y="#{y2 + 18}" text-anchor="middle" class="text-axis">#{t}</text>|)
    end)

    x_fin = ancho_lbl + total_tiempo * px
    y_eje = alto_total - margen_inf + 10
    Util.escribir_linea(file, ~s|  <line x1="#{ancho_lbl}" y1="#{y_eje}" x2="#{x_fin}" y2="#{y_eje}" class="axis" />|)
  end

  defp dibujar_barras(file, plan, mapa_tareas, ancho_lbl, px, margen_sup, alto_fila) do
    plan.orden
    |> Enum.reduce(0, fn id_tarea, inicio_t ->
      t = Map.fetch!(mapa_tareas, id_tarea)
      fin_t = inicio_t + t.duracion
      fuera_de_plazo = fin_t > t.plazo

      idx = Enum.find_index(plan.orden, &(&1 == id_tarea))
      y_pos = margen_sup + idx * alto_fila
      x_bar = ancho_lbl + inicio_t * px
      ancho_bar = t.duracion * px
      clase_barra = if fuera_de_plazo, do: "bar-late", else: "bar-ok"

      id_escapado = Util.escape_xml(t.id)

      Util.escribir_linea(file, ~s|  <text x="#{ancho_lbl - 15}" y="#{y_pos + 22}" text-anchor="end" class="label">Tarea #{id_escapado}</text>|)
      Util.escribir_linea(file, ~s|  <rect x="#{x_bar}" y="#{y_pos + 5}" width="#{ancho_bar}" height="26" class="#{clase_barra}" />|)
      Util.escribir_linea(file, ~s|  <text x="#{x_bar + 8}" y="#{y_pos + 22}" class="text-time">[#{inicio_t} - #{fin_t}] (Plazo: #{t.plazo})</text>|)

      fin_t
    end)
  end

  defp dibujar_leyenda(file, ancho_lbl, alto_total) do
    y_leyenda = alto_total - 18
    Util.escribir_linea(file, ~s|  <rect x="#{ancho_lbl}" y="#{y_leyenda - 10}" width="14" height="14" class="bar-ok" />|)
    Util.escribir_linea(file, ~s|  <text x="#{ancho_lbl + 20}" y="#{y_leyenda}" class="text-axis">A tiempo</text>|)
    Util.escribir_linea(file, ~s|  <rect x="#{ancho_lbl + 100}" y="#{y_leyenda - 10}" width="14" height="14" class="bar-late" />|)
    Util.escribir_linea(file, ~s|  <text x="#{ancho_lbl + 120}" y="#{y_leyenda}" class="text-axis">Fuera de plazo</text>|)
  end
end
