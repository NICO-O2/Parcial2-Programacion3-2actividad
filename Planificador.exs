defmodule Planificador do
  def ejecutar(archivo_entrada \\ "tareas.csv") do
    case cargar_y_validar(archivo_entrada) do
      {:error, errores} ->
        escribir_validacion(errores)
        Util.mostrar_mensaje("El archivo de tareas contiene errores. Revisa validacion_tareas.txt")

      {:ok, []} ->
        escribir_validacion([])
        escribir_resumen_vacio()
        SVGGenerator.generar_vacio()
        Util.con_archivo("planes.csv", &Util.escribir_linea(&1, "id;orden;duracion_total;penalizacion"))
        Util.mostrar_mensaje("Proyecto vacío procesado correctamente.")

      {:ok, tareas} ->
        escribir_validacion([])
        mapa_tareas = Map.new(tareas, fn t -> {t.id, t} end)

        {total_planes, min_pen, mejores_planes} = BuscadorPlanes.ejecutar(mapa_tareas)

        escribir_resumen(total_planes, min_pen, mejores_planes)
        SVGGenerator.generar(List.first(mejores_planes), mapa_tareas)

        Util.mostrar_mensaje("Procesamiento completado con éxito.")
    end
  end

  defp cargar_y_validar(archivo) do
    unless File.exists?(archivo) do
      {:error, ["El archivo #{archivo} no existe."]}
    else
      lineas_con_num = archivo |> Util.registros() |> Enum.to_list()

      if lineas_con_num == [] do
        {:ok, []}
      else
        {parsed_tareas, parse_errores} = Validador.parsear_lineas(lineas_con_num, [], [])

        if parse_errores != [] do
          {:error, parse_errores}
        else
          errores_val = Validador.validar_grafo_y_tareas(parsed_tareas)
          if errores_val != [], do: {:error, errores_val}, else: {:ok, parsed_tareas}
        end
      end
    end
  end

  defp escribir_validacion([]) do
    Util.con_archivo("validacion_tareas.txt", &Util.escribir_linea(&1, "OK: El archivo de tareas es completamente válido."))
  end

  defp escribir_validacion(errores) do
    Util.con_archivo("validacion_tareas.txt", fn file ->
      Util.escribir_linea(file, "ERRORES DETECTADOS:")
      Enum.each(errores, fn err -> Util.escribir_linea(file, "- #{err}") end)
    end)
  end

  defp escribir_resumen_vacio do
    Util.con_archivo("resumen_tareas.txt", fn file ->
      Util.escribir_linea(file, "======================================")
      Util.escribir_linea(file, "RESUMEN DE EJECUCIÓN DEL PROYECTO")
      Util.escribir_linea(file, "======================================")
      Util.escribir_linea(file, "Estado: Proyecto vacío sin tareas.")
      Util.escribir_linea(file, "Total de planes válidos: 0")
      Util.escribir_linea(file, "Penalización mínima: N/A")
    end)
  end

  defp escribir_resumen(total_planes, min_penalizacion, mejores_planes) do
    Util.con_archivo("resumen_tareas.txt", fn file ->
      Util.escribir_linea(file, "======================================")
      Util.escribir_linea(file, "RESUMEN DE EJECUCIÓN DEL PROYECTO")
      Util.escribir_linea(file, "======================================")
      Util.escribir_linea(file, "Total de planes válidos: #{total_planes}")
      Util.escribir_linea(file, "Penalización mínima alcanzada: #{min_penalizacion}")
      Util.escribir_linea(file, "Planes óptimos con penalización mínima (#{length(mejores_planes)}):")

      Enum.each(mejores_planes, fn p ->
        Util.escribir_linea(file, "  - Orden: " <> Enum.join(p.orden, " !' "))
      end)
    end)
  end
end

Planificador.ejecutar()
