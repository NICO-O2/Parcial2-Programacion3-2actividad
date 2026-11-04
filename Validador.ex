defmodule Validador do
  def parsear_lineas([], acc_t, acc_err), do: {Enum.reverse(acc_t), Enum.reverse(acc_err)}
  def parsear_lineas([{num_linea, linea} | rest], acc_t, acc_err) do
    case String.split(linea, ";") do
      [id, dur_str, plazo_str, deps_str] ->
        errores = []

        duracion = case Integer.parse(dur_str) do
          {val, ""} when val > 0 -> val
          _ -> ["Línea #{num_linea}: Duración inválida en '#{id}' (#{dur_str})" | errores]
        end

        plazo = case Integer.parse(plazo_str) do
          {val, ""} when val >= 0 -> val
          _ -> ["Línea #{num_linea}: Plazo inválido en '#{id}' (#{plazo_str})" | errores]
        end

        deps = if deps_str in ["-", ""], do: [], else: String.split(deps_str, "|")

        if String.contains?(id, ["#", "|", ";"]) do
          errores = ["Línea #{num_linea}: ID '#{id}' contiene caracteres no permitidos" | errores]
        end

        if is_list(duracion) or is_list(plazo) do
          # Captura errores de parseo numérico si los hubo
          errs = Enum.filter([duracion, plazo], &is_list/1) |> List.flatten()
          parsear_lineas(rest, acc_t, errs ++ errores ++ acc_err)
        else
          tarea = %Tarea{id: id, duracion: duracion, plazo: plazo, dependencias: deps}
          parsear_lineas(rest, [tarea | acc_t], acc_err)
        end

      _ ->
        parsear_lineas(rest, acc_t, ["Línea #{num_linea}: Formato de línea inválido" | acc_err])
    end
  end

  def validar_grafo_y_tareas(tareas) do
    ids = Enum.map(tareas, & &1.id)
    ids_set = MapSet.new(ids)

    duplicados = ids -- Enum.uniq(ids)
    err_duplicados = Enum.map(Enum.uniq(duplicados), &"ID duplicado detectado: #{&1}")

    err_deps = Enum.flat_map(tareas, fn t ->
      err_desconocidas =
        t.dependencias
        |> Enum.filter(& not MapSet.member?(ids_set, &1))
        |> Enum.map(&"La tarea '#{t.id}' depende de la tarea desconocida '#{&1}'")

      err_self = if Util.miembro?(t.dependencias, t.id), do: ["La tarea '#{t.id}' no puede depender de sí misma"], else: []
      err_rep = if length(t.dependencias) != length(Enum.uniq(t.dependencias)), do: ["La tarea '#{t.id}' tiene dependencias repetidas"], else: []

      err_desconocidas ++ err_self ++ err_rep
    end)

    err_ciclos =
      if err_duplicados == [] and err_deps == [] do
        detectar_ciclos(tareas) |> Enum.map(&"Ciclo detectado: " <> Enum.join(&1, " -> "))
      else
        []
      end

    err_duplicados ++ err_deps ++ err_ciclos
  end

  defp detectar_ciclos(tareas) do
    adj = Map.new(tareas, fn t -> {t.id, t.dependencias} end)

    Map.keys(adj)
    |> Enum.reduce(MapSet.new(), fn nodo, acc ->
      dfs_ciclos(nodo, adj, [nodo], MapSet.new([nodo]), acc)
    end)
    |> MapSet.to_list()
  end

  defp dfs_ciclos(actual, adj, camino, visitados, acc) do
    vecinos = Map.get(adj, actual, [])

    Enum.reduce(vecinos, acc, fn vecino, acc_inner ->
      if MapSet.member?(visitados, vecino) do
        idx = Enum.find_index(camino, &(&1 == vecino))
        sub_ciclo = Enum.slice(camino, idx..-1)
        MapSet.put(acc_inner, normalizar_ciclo(sub_ciclo))
      else
        dfs_ciclos(vecino, adj, camino ++ [vecino], MapSet.put(visitados, vecino), acc_inner)
      end
    end)
  end

  defp normalizar_ciclo(ciclo) do
    min_elem = Enum.min(ciclo)
    indices = Enum.with_index(ciclo) |> Enum.filter(fn {v, _} -> v == min_elem end) |> Enum.map(&elem(&1, 1))

    indices
    |> Enum.map(fn idx ->
      {head, tail} = Enum.split(ciclo, idx)
      tail ++ head
    end)
    |> Enum.min()
  end
end
