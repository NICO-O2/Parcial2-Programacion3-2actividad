defmodule BuscadorPlanes do
  def ejecutar(mapa_tareas) do
    ids_todas = Map.keys(mapa_tareas) |> Enum.sort()
    estado_inicial = {0, nil, []}

    {total_planes, min_pen, mejores} =
      Util.con_archivo("planes.csv", fn file ->
        Util.escribir_linea(file, "id;orden;duracion_total;penalizacion")
        hacer_busqueda([], MapSet.new(), 0, 0, %{}, ids_todas, mapa_tareas, file, estado_inicial)
      end)

    {total_planes, min_pen, Enum.reverse(mejores)}
  end

  defp hacer_busqueda(orden, terminadas, tiempo, penalizacion, finalizaciones, ids_todas, mapa_tareas, file, estado) do
    pendientes = Enum.filter(ids_todas, & not MapSet.member?(terminadas, &1))

    if pendientes == [] do
      duracion_total = tiempo
      plan = %Plan{orden: orden, finalizaciones: finalizaciones, penalizacion: penalizacion, duracion_total: duracion_total}

      {cant, min_pen, mejores} = estado
      nuevo_cant = cant + 1

      Util.escribir_linea(file, "#{nuevo_cant};#{Enum.join(orden, " !' ")};#{duracion_total};#{penalizacion}")

      cond do
        min_pen == nil or penalizacion < min_pen -> {nuevo_cant, penalizacion, [plan]}
        penalizacion == min_pen -> {nuevo_cant, min_pen, [plan | mejores]}
        true -> {nuevo_cant, min_pen, mejores}
      end
    else
      habilitadas =
        pendientes
        |> Enum.filter(fn id ->
          t = Map.fetch!(mapa_tareas, id)
          Enum.all?(t.dependencias, &MapSet.member?(terminadas, &1))
        end)
        |> Enum.sort()

      Enum.reduce(habilitadas, estado, fn id, acc_estado ->
        t = Map.fetch!(mapa_tareas, id)
        fin_t = tiempo + t.duracion
        pen_t = max(0, fin_t - t.plazo)

        hacer_busqueda(
          orden ++ [id],
          MapSet.put(terminadas, id),
          fin_t,
          penalizacion + pen_t,
          Map.put(finalizaciones, id, fin_t),
          ids_todas,
          mapa_tareas,
          file,
          acc_estado
        )
      end)
    end
  end
end
