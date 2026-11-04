Code.require_file("Util.ex")
Code.require_file("Util2.ex")

defmodule Terreno do
  @moduledoc """
  Struct que representa un tipo de casilla del edificio (una fila de terrenos.csv)
  - simbolo: simbolo que aparece en edificio.txt (un solo caracter)
  - nombre: nombre del terreno
  - transitable: true si el robot puede entrar, false si no (por ejemplo una pared)
  - costo: energia que consume entrar a la casilla (entero no negativo)
  """
  defstruct [:simbolo, :nombre, :transitable, :costo]
end

defmodule Recorrido do
  @moduledoc """
  Struct que representa un recorrido simple de S a M
  - posiciones: lista de posiciones {fila, columna} desde S hasta M
  - energia: energia total consumida (la casilla inicial no consume)
  """
  defstruct [:posiciones, :energia]
end

defmodule Rescate do
  @moduledoc """
  Modulo del Problema 1: robot de rescate con energia limitada y mapa SVG
  - Lee edificio.txt, terrenos.csv y bateria.txt (File.stream! de forma perezosa)
  - Valida la entrada con funciones recursivas propias
  - Genera un Stream infinito de relajacion de energia minima (filtro previo)
  - Encuentra recursivamente todos los recorridos simples de S a M sin superar B
  - Genera recorridos_rescate.csv, resumen_rescate.txt y ruta_optima.svg
  - Autores: (nombres del grupo)
  - fecha: (fecha de entrega)
  """

  # Simbolos fijos que define el enunciado: inicio, meta y borde del edificio
  @inicio "S"
  @meta "M"
  @pared "X"

  # Tamano en pixeles de cada casilla del SVG
  @lado 40

  # Orden fijo de los movimientos: arriba, derecha, abajo, izquierda
  @movimientos [{-1, 0}, {0, 1}, {1, 0}, {0, -1}]

  # Colores del SVG: los terrenos transitables toman un color de la paleta
  @paleta ["#f5f0e1", "#a47551", "#81c784", "#e57373", "#ffd54f", "#4fc3f7", "#ce93d8", "#ffab91"]
  @color_pared "#9e9e9e"
  @color_ruta "#1565c0"

  # ---------------------------------------------------------------
  # Programa principal
  # ---------------------------------------------------------------

  @doc """
  Funcion principal. Verifica que existan los tres archivos de entrada y
  lanza el proceso. Si falta alguno muestra un aviso claro
  ## PARAMETRO
    - carpeta_entrada: carpeta con edificio.txt, terrenos.csv y bateria.txt
      (por defecto "entrada/rescate")
    - carpeta_salida: carpeta donde se escriben las salidas (por defecto "salida/rescate")

  ## EJEMPLO
    iex > Rescate.ejecutar()
    iex > Rescate.ejecutar("entrada/rescate", "salida/rescate")
  """
  def ejecutar(carpeta_entrada \\ "entrada/rescate", carpeta_salida \\ "salida/rescate") do
    ruta_edificio = Path.join(carpeta_entrada, "edificio.txt")
    ruta_terrenos = Path.join(carpeta_entrada, "terrenos.csv")
    ruta_bateria = Path.join(carpeta_entrada, "bateria.txt")

    faltantes = Enum.reject([ruta_edificio, ruta_terrenos, ruta_bateria], &File.exists?/1)

    case faltantes do
      [] ->
        procesar(ruta_edificio, ruta_terrenos, ruta_bateria, carpeta_salida)

      _ ->
        Enum.each(faltantes, fn ruta ->
          Util.mostrar_error("ERROR: no se encontró el archivo requerido: #{ruta}")
        end)

        Util.mostrar_error("No se puede continuar sin los archivos de entrada.")
    end
  end

  @doc """
  Funcion que lee los archivos, valida la entrada y, si no hay errores,
  resuelve el problema. Si hay errores solo escribe validacion_edificio.txt
  ## PARAMETRO
    - ruta_edificio: ruta de edificio.txt
    - ruta_terrenos: ruta de terrenos.csv
    - ruta_bateria: ruta de bateria.txt
    - carpeta_salida: carpeta donde se escriben las salidas

  ## EJEMPLO
    iex > Rescate.procesar("entrada/rescate/edificio.txt", "entrada/rescate/terrenos.csv", "entrada/rescate/bateria.txt", "salida/rescate")
  """
  def procesar(ruta_edificio, ruta_terrenos, ruta_bateria, carpeta_salida) do
    lecturas = leer_terrenos(ruta_terrenos)
    filas = leer_edificio(ruta_edificio)
    lineas_bateria = ruta_bateria |> Util.registros() |> Enum.to_list()

    terrenos = terrenos_validos(lecturas)
    errores = errores_de_lectura(lecturas) ++ validar_edificio(terrenos, filas, lineas_bateria)

    ruta_validacion = Path.join(carpeta_salida, "validacion_edificio.txt")
    escribir_validacion(ruta_validacion, errores)

    case errores do
      [] ->
        [{_linea, texto}] = lineas_bateria
        resolver(terrenos, filas, String.to_integer(texto), carpeta_salida)

      _ ->
        Util.mostrar_error(
          "Se encontraron #{length(errores)} errores en la entrada. " <>
            "Revise #{ruta_validacion}. No se inició la búsqueda."
        )
    end
  end

  @doc """
  Funcion que resuelve el problema con una entrada ya validada:
  1. Genera el Stream de relajacion y escribe expansion_energia.txt
  2. Si la meta tiene costo alcanzable, enumera los recorridos recursivamente
  3. Escribe recorridos_rescate.csv, resumen_rescate.txt y ruta_optima.svg
  ## PARAMETRO
    - terrenos: lista de {linea, %Terreno{}}
    - filas: lista de {linea, [simbolos]} del edificio
    - bateria: presupuesto maximo de energia B (entero positivo)
    - carpeta_salida: carpeta donde se escriben las salidas

  ## EJEMPLO
    iex > Rescate.resolver(terrenos, filas, 10, "salida/rescate")
  """
  def resolver(terrenos, filas, bateria, carpeta_salida) do
    problema = construir_problema(terrenos, filas, bateria)

    # Stream infinito de relajación de energía (se usa como filtro previo)
    estados = estados_de_energia(problema)
    indice = indice_de_estabilizacion(estados)
    estado_final = Enum.at(estados, indice)

    escribir_expansion(
      Path.join(carpeta_salida, "expansion_energia.txt"),
      problema,
      estados,
      indice,
      estado_final
    )

    # Si la meta no tiene costo alcanzable, se omite la enumeración recursiva
    recorridos =
      case Map.fetch(estado_final, problema.meta) do
        {:ok, _costo} -> explorar(problema, problema.inicio, [problema.inicio], 0)
        :error -> []
      end

    numerados =
      recorridos
      |> Enum.with_index(1)
      |> Enum.map(fn {recorrido, id} -> {id, recorrido} end)

    escribir_csv(Path.join(carpeta_salida, "recorridos_rescate.csv"), numerados)

    resumen = construir_resumen(problema, numerados)
    escribir_resumen(Path.join(carpeta_salida, "resumen_rescate.txt"), resumen)
    Enum.each(resumen, &Util.mostrar_mensaje/1)

    # En caso de empate, min_by devuelve el primero encontrado
    mejor =
      case numerados do
        [] -> nil
        _ -> Enum.min_by(numerados, fn {_id, recorrido} -> recorrido.energia end)
      end

    escribir_svg(Path.join(carpeta_salida, "ruta_optima.svg"), problema, mejor)
    Util.mostrar_mensaje("Archivos generados en #{carpeta_salida}")
  end

  # ---------------------------------------------------------------
  # Lectura (File.stream! a traves de Util.registros, de forma perezosa)
  # ---------------------------------------------------------------

  @doc """
  Funcion para leer terrenos.csv de forma perezosa y convertir cada registro.
  Devuelve una lista con un resultado por cada linea de datos
  ## PARAMETRO
    - ruta: ruta del archivo terrenos.csv

  ## EJEMPLO
    iex > Rescate.leer_terrenos("entrada/rescate/terrenos.csv")
    [{:ok, 1, %Terreno{simbolo: "X", nombre: "pared", transitable: false, costo: 0}}, ...]
  """
  def leer_terrenos(ruta) do
    ruta
    |> Util.registros()
    |> Stream.map(&convertir_terreno/1)
    |> Enum.to_list()
  end

  @doc """
  Funcion para convertir un registro {linea, texto} en un terreno.
  Devuelve {:ok, linea, terreno} o {:error, linea, mensaje} si no tiene 4 campos
  ## PARAMETRO
    - registro: tupla {numero_de_linea, texto} con formato simbolo,nombre,transitable,costo

  ## EJEMPLO
    iex > Rescate.convertir_terreno({1, "X,pared,no,0"})
    {:ok, 1, %Terreno{simbolo: "X", nombre: "pared", transitable: false, costo: 0}}
  """
  def convertir_terreno({linea, texto}) do
    campos = texto |> String.split(",") |> Enum.map(&String.trim/1)

    case campos do
      [simbolo, nombre, transitable, costo] ->
        convertir_campos_terreno(linea, simbolo, nombre, transitable, costo)

      _ ->
        {:error, linea,
         "terrenos.csv, línea #{linea}: se esperaban 4 campos " <>
           "(simbolo,nombre,transitable,costo) y hay #{length(campos)}"}
    end
  end

  @doc """
  Funcion para convertir los 4 campos de un registro en un %Terreno{}.
  Exige un simbolo de un caracter, transitable "si" o "no" y un costo entero
  no negativo; si no, devuelve {:error, linea, mensaje}
  ## PARAMETRO
    - linea: linea fisica del registro
    - simbolo: texto del simbolo
    - nombre: nombre del terreno
    - transitable: "si" o "no"
    - costo: texto con el costo

  ## EJEMPLO
    iex > Rescate.convertir_campos_terreno(2, ".", "pasillo", "si", "1")
    {:ok, 2, %Terreno{simbolo: ".", nombre: "pasillo", transitable: true, costo: 1}}
  """
  def convertir_campos_terreno(linea, simbolo, nombre, transitable, costo) do
    case {String.length(simbolo) == 1, transitable, Integer.parse(costo)} do
      {true, "si", {valor, ""}} when valor >= 0 ->
        {:ok, linea, %Terreno{simbolo: simbolo, nombre: nombre, transitable: true, costo: valor}}

      {true, "no", {valor, ""}} when valor >= 0 ->
        {:ok, linea, %Terreno{simbolo: simbolo, nombre: nombre, transitable: false, costo: valor}}

      _ ->
        {:error, linea,
         "terrenos.csv, línea #{linea}: registro incorrecto " <>
           "(símbolo de un carácter, transitable si/no y costo entero no negativo)"}
    end
  end

  @doc """
  Funcion para obtener los mensajes de los registros mal formados
  ## PARAMETRO
    - lecturas: lista de resultados de leer_terrenos/1

  ## EJEMPLO
    iex > Rescate.errores_de_lectura([{:error, 5, "mensaje"}])
    ["mensaje"]
  """
  def errores_de_lectura(lecturas) do
    lecturas
    |> Enum.filter(fn lectura -> elem(lectura, 0) == :error end)
    |> Enum.map(fn {:error, _linea, mensaje} -> mensaje end)
  end

  @doc """
  Funcion para obtener los terrenos bien formados como lista de {linea, %Terreno{}}
  ## PARAMETRO
    - lecturas: lista de resultados de leer_terrenos/1

  ## EJEMPLO
    iex > Rescate.terrenos_validos([{:ok, 1, %Terreno{simbolo: "X"}}, {:error, 2, "mensaje"}])
    [{1, %Terreno{simbolo: "X", nombre: nil, transitable: nil, costo: nil}}]
  """
  def terrenos_validos(lecturas) do
    lecturas
    |> Enum.filter(fn lectura -> elem(lectura, 0) == :ok end)
    |> Enum.map(fn {:ok, linea, terreno} -> {linea, terreno} end)
  end

  @doc """
  Funcion para leer edificio.txt de forma perezosa. Cada fila se divide en
  sus simbolos (separados por espacios)
  ## PARAMETRO
    - ruta: ruta del archivo edificio.txt

  ## EJEMPLO
    iex > Rescate.leer_edificio("entrada/rescate/edificio.txt")
    [{1, ["X", "X", "X", "X", "X", "X"]}, {2, ["X", "S", ".", "L", "M", "X"]}, ...]
  """
  def leer_edificio(ruta) do
    ruta
    |> Util.registros()
    |> Stream.map(fn {linea, texto} -> {linea, String.split(texto)} end)
    |> Enum.to_list()
  end

  # ---------------------------------------------------------------
  # Validacion previa (solo funciones recursivas propias, sin Enum ni Stream)
  # Cada funcion devuelve una lista de mensajes de error.
  # ---------------------------------------------------------------

  @doc """
  Funcion que reune todas las validaciones previas de la entrada
  ## PARAMETRO
    - terrenos: lista de {linea, %Terreno{}}
    - filas: lista de {linea, [simbolos]} del edificio
    - lineas_bateria: lista de {linea, texto} de bateria.txt

  ## EJEMPLO
    iex > terrenos = [
    ...>   {1, %Terreno{simbolo: "X", nombre: "pared", transitable: false, costo: 0}},
    ...>   {2, %Terreno{simbolo: "S", nombre: "inicio", transitable: true, costo: 0}},
    ...>   {3, %Terreno{simbolo: "M", nombre: "meta", transitable: true, costo: 1}}
    ...> ]
    iex > filas = [{1, ["X", "X", "X", "X"]}, {2, ["X", "S", "M", "X"]}, {3, ["X", "X", "X", "X"]}]
    iex > Rescate.validar_edificio(terrenos, filas, [{1, "1"}])
    []
  """
  def validar_edificio(terrenos, filas, lineas_bateria) do
    definidos = simbolos_de(terrenos)

    validar_simbolos_repetidos(terrenos, []) ++
      validar_costos_terrenos(terrenos) ++
      validar_no_vacio(filas) ++
      validar_rectangular(filas) ++
      validar_simbolos_definidos(filas, 0, definidos) ++
      validar_unico(posiciones_de(filas, @inicio, 0), @inicio) ++
      validar_unico(posiciones_de(filas, @meta, 0), @meta) ++
      validar_borde(filas, 0, length(filas)) ++
      validar_bateria(lineas_bateria)
  end

  @doc """
  Funcion recursiva para obtener la lista de simbolos de los terrenos
  ## PARAMETRO
    - terrenos: lista de {linea, %Terreno{}}

  ## EJEMPLO
    iex > Rescate.simbolos_de([{1, %Terreno{simbolo: "X"}}, {2, %Terreno{simbolo: "."}}])
    ["X", "."]
  """
  def simbolos_de([]), do: []
  def simbolos_de([{_linea, terreno} | resto]), do: [terreno.simbolo | simbolos_de(resto)]

  @doc """
  Funcion recursiva para validar que la tabla de terrenos no tenga simbolos repetidos
  ## PARAMETRO
    - terrenos: lista de {linea, %Terreno{}}
    - vistos: lista de simbolos ya revisados (al comenzar es [])

  ## EJEMPLO
    iex > Rescate.validar_simbolos_repetidos([{1, %Terreno{simbolo: "."}}, {2, %Terreno{simbolo: "."}}], [])
    ["terrenos.csv, línea 2: el símbolo '.' está repetido"]
  """
  def validar_simbolos_repetidos([], _vistos), do: []

  def validar_simbolos_repetidos([{linea, terreno} | resto], vistos) do
    siguientes = validar_simbolos_repetidos(resto, [terreno.simbolo | vistos])

    case Util.miembro?(vistos, terreno.simbolo) do
      true ->
        ["terrenos.csv, línea #{linea}: el símbolo '#{terreno.simbolo}' está repetido" | siguientes]

      false ->
        siguientes
    end
  end

  @doc """
  Funcion recursiva para validar que las casillas transitables distintas de S
  tengan costo positivo
  ## PARAMETRO
    - terrenos: lista de {linea, %Terreno{}}

  ## EJEMPLO
    iex > Rescate.validar_costos_terrenos([{3, %Terreno{simbolo: "L", transitable: true, costo: 0}}])
    ["terrenos.csv, línea 3: el terreno transitable 'L' debe tener costo positivo"]
  """
  def validar_costos_terrenos([]), do: []

  def validar_costos_terrenos([
        {linea, %Terreno{transitable: true, costo: 0, simbolo: simbolo}} | resto
      ])
      when simbolo != @inicio do
    [
      "terrenos.csv, línea #{linea}: el terreno transitable '#{simbolo}' debe tener costo positivo"
      | validar_costos_terrenos(resto)
    ]
  end

  def validar_costos_terrenos([_otro | resto]), do: validar_costos_terrenos(resto)

  @doc """
  Funcion para validar que la cuadricula no este vacia
  ## PARAMETRO
    - filas: lista de {linea, [simbolos]} del edificio

  ## EJEMPLO
    iex > Rescate.validar_no_vacio([])
    ["edificio.txt: el edificio está vacío"]
  """
  def validar_no_vacio([]), do: ["edificio.txt: el edificio está vacío"]
  def validar_no_vacio(_filas), do: []

  @doc """
  Funcion recursiva para validar que la cuadricula sea rectangular: todas las
  filas deben tener tantos simbolos como la primera
  ## PARAMETRO
    - filas: lista de {linea, [simbolos]} del edificio

  ## EJEMPLO
    iex > Rescate.validar_rectangular([{1, ["X", "X"]}, {2, ["X"]}])
    ["edificio.txt, línea 2: la fila tiene 1 símbolos y se esperaban 2"]
  """
  def validar_rectangular([]), do: []

  def validar_rectangular([{_linea, primera} | resto]),
    do: validar_anchos(resto, length(primera))

  @doc """
  Funcion recursiva que compara el ancho de cada fila con el ancho esperado
  ## PARAMETRO
    - filas: lista de {linea, [simbolos]} que faltan por revisar
    - ancho: numero de simbolos que debe tener cada fila

  ## EJEMPLO
    iex > Rescate.validar_anchos([{2, ["X"]}], 2)
    ["edificio.txt, línea 2: la fila tiene 1 símbolos y se esperaban 2"]
  """
  def validar_anchos([], _ancho), do: []

  def validar_anchos([{linea, simbolos} | resto], ancho) do
    siguientes = validar_anchos(resto, ancho)

    case length(simbolos) == ancho do
      true ->
        siguientes

      false ->
        [
          "edificio.txt, línea #{linea}: la fila tiene #{length(simbolos)} símbolos " <>
            "y se esperaban #{ancho}"
          | siguientes
        ]
    end
  end

  @doc """
  Funcion recursiva para validar que todos los simbolos del edificio esten
  definidos en terrenos.csv
  ## PARAMETRO
    - filas: lista de {linea, [simbolos]} del edificio
    - fila: indice de la fila que se revisa (al comenzar es 0)
    - definidos: lista de simbolos definidos en terrenos.csv

  ## EJEMPLO
    iex > Rescate.validar_simbolos_definidos([{1, ["X", "Z"]}], 0, ["X"])
    ["edificio.txt, coordenada {0, 1} (línea 1): el símbolo 'Z' no está definido en terrenos.csv"]
  """
  def validar_simbolos_definidos([], _fila, _definidos), do: []

  def validar_simbolos_definidos([{linea, simbolos} | resto], fila, definidos) do
    validar_simbolos_fila(simbolos, fila, 0, linea, definidos) ++
      validar_simbolos_definidos(resto, fila + 1, definidos)
  end

  @doc """
  Funcion recursiva que revisa los simbolos de una sola fila
  ## PARAMETRO
    - simbolos: simbolos de la fila que faltan por revisar
    - fila: indice de la fila
    - columna: indice de la columna que se revisa (al comenzar es 0)
    - linea: linea fisica de la fila en el archivo
    - definidos: lista de simbolos definidos en terrenos.csv

  ## EJEMPLO
    iex > Rescate.validar_simbolos_fila(["X", "Z"], 0, 0, 1, ["X"])
    ["edificio.txt, coordenada {0, 1} (línea 1): el símbolo 'Z' no está definido en terrenos.csv"]
  """
  def validar_simbolos_fila([], _fila, _columna, _linea, _definidos), do: []

  def validar_simbolos_fila([simbolo | resto], fila, columna, linea, definidos) do
    siguientes = validar_simbolos_fila(resto, fila, columna + 1, linea, definidos)

    case Util.miembro?(definidos, simbolo) do
      true ->
        siguientes

      false ->
        [
          "edificio.txt, coordenada {#{fila}, #{columna}} (línea #{linea}): " <>
            "el símbolo '#{simbolo}' no está definido en terrenos.csv"
          | siguientes
        ]
    end
  end

  @doc """
  Funcion recursiva para obtener las posiciones donde aparece un simbolo
  ## PARAMETRO
    - filas: lista de {linea, [simbolos]} del edificio
    - simbolo: simbolo que se busca
    - fila: indice de la fila que se revisa (al comenzar es 0)

  ## EJEMPLO
    iex > Rescate.posiciones_de([{1, ["X", "S"]}, {2, ["S", "X"]}], "S", 0)
    [{0, 1}, {1, 0}]
  """
  def posiciones_de([], _simbolo, _fila), do: []

  def posiciones_de([{_linea, simbolos} | resto], simbolo, fila) do
    posiciones_en_fila(simbolos, simbolo, fila, 0) ++ posiciones_de(resto, simbolo, fila + 1)
  end

  @doc """
  Funcion recursiva para obtener las posiciones de un simbolo dentro de una fila
  ## PARAMETRO
    - simbolos: simbolos de la fila que faltan por revisar
    - simbolo: simbolo que se busca
    - fila: indice de la fila
    - columna: indice de la columna que se revisa (al comenzar es 0)

  ## EJEMPLO
    iex > Rescate.posiciones_en_fila(["S", "X", "S"], "S", 0, 0)
    [{0, 0}, {0, 2}]
  """
  def posiciones_en_fila([], _simbolo, _fila, _columna), do: []

  def posiciones_en_fila([simbolo | resto], simbolo, fila, columna) do
    [{fila, columna} | posiciones_en_fila(resto, simbolo, fila, columna + 1)]
  end

  def posiciones_en_fila([_otro | resto], simbolo, fila, columna) do
    posiciones_en_fila(resto, simbolo, fila, columna + 1)
  end

  @doc """
  Funcion para validar que un simbolo (S o M) aparezca exactamente una vez
  ## PARAMETRO
    - posiciones: lista de posiciones donde aparece el simbolo
    - simbolo: simbolo que se valida

  ## EJEMPLO
    iex > Rescate.validar_unico([], "S")
    ["edificio.txt: no existe ningún 'S'; debe haber exactamente uno"]
    iex > Rescate.validar_unico([{1, 1}], "S")
    []
  """
  def validar_unico([_unica], _simbolo), do: []

  def validar_unico([], simbolo) do
    ["edificio.txt: no existe ningún '#{simbolo}'; debe haber exactamente uno"]
  end

  def validar_unico(posiciones, simbolo) do
    [
      "edificio.txt: hay #{length(posiciones)} símbolos '#{simbolo}' en las coordenadas " <>
        "#{inspect(posiciones)}; debe haber exactamente uno"
    ]
  end

  @doc """
  Funcion recursiva para validar que el borde completo del edificio este
  formado por X
  ## PARAMETRO
    - filas: lista de {linea, [simbolos]} del edificio
    - fila: indice de la fila que se revisa (al comenzar es 0)
    - total: numero total de filas del edificio

  ## EJEMPLO
    iex > Rescate.validar_borde([{1, ["X", "X"]}, {2, ["X", "."]}], 0, 2)
    ["edificio.txt, coordenada {1, 1} (línea 2): el borde debe ser 'X' y hay '.'"]
  """
  def validar_borde([], _fila, _total), do: []

  def validar_borde([{linea, simbolos} | resto], fila, total) do
    validar_borde_fila(simbolos, fila, 0, length(simbolos), linea, total) ++
      validar_borde(resto, fila + 1, total)
  end

  @doc """
  Funcion recursiva que revisa el borde dentro de una sola fila. Una casilla
  es de borde si esta en la primera o ultima fila, o en la primera o ultima columna
  ## PARAMETRO
    - simbolos: simbolos de la fila que faltan por revisar
    - fila: indice de la fila
    - columna: indice de la columna que se revisa (al comenzar es 0)
    - ancho: numero de simbolos de la fila
    - linea: linea fisica de la fila en el archivo
    - total: numero total de filas del edificio

  ## EJEMPLO
    iex > Rescate.validar_borde_fila(["X", "."], 1, 0, 2, 2, 2)
    ["edificio.txt, coordenada {1, 1} (línea 2): el borde debe ser 'X' y hay '.'"]
  """
  def validar_borde_fila([], _fila, _columna, _ancho, _linea, _total), do: []

  def validar_borde_fila([simbolo | resto], fila, columna, ancho, linea, total) do
    siguientes = validar_borde_fila(resto, fila, columna + 1, ancho, linea, total)
    es_borde = fila == 0 or fila == total - 1 or columna == 0 or columna == ancho - 1

    case es_borde and simbolo != @pared do
      true ->
        [
          "edificio.txt, coordenada {#{fila}, #{columna}} (línea #{linea}): " <>
            "el borde debe ser '#{@pared}' y hay '#{simbolo}'"
          | siguientes
        ]

      false ->
        siguientes
    end
  end

  @doc """
  Funcion para validar que bateria.txt tenga un unico entero positivo
  ## PARAMETRO
    - lineas: lista de {linea, texto} con las lineas de datos de bateria.txt

  ## EJEMPLO
    iex > Rescate.validar_bateria([{1, "10"}])
    []
    iex > Rescate.validar_bateria([{1, "diez"}])
    ["bateria.txt, línea 1: 'diez' no es un entero positivo"]
  """
  def validar_bateria([]) do
    ["bateria.txt: no contiene ningún dato; se esperaba un entero positivo"]
  end

  def validar_bateria([{linea, texto}]) do
    case Integer.parse(texto) do
      {valor, ""} when valor > 0 -> []
      _ -> ["bateria.txt, línea #{linea}: '#{texto}' no es un entero positivo"]
    end
  end

  def validar_bateria(lineas) do
    ["bateria.txt: debe tener una sola línea de datos y tiene #{length(lineas)}"]
  end

  @doc """
  Funcion para escribir validacion_edificio.txt con todos los errores
  encontrados (o un aviso si no hay ninguno)
  ## PARAMETRO
    - ruta: ruta del archivo de salida
    - errores: lista de mensajes de error

  ## EJEMPLO
    iex > Rescate.escribir_validacion("salida/rescate/validacion_edificio.txt", [])
  """
  def escribir_validacion(ruta, errores) do
    Util.con_archivo(ruta, fn archivo ->
      Util.escribir_linea(archivo, "VALIDACIÓN DEL EDIFICIO")

      case errores do
        [] ->
          Util.escribir_linea(archivo, "Sin errores: la entrada es consistente.")

        _ ->
          Util.escribir_linea(archivo, "Errores encontrados: #{length(errores)}")

          errores
          |> Enum.with_index(1)
          |> Enum.each(fn {mensaje, numero} ->
            Util.escribir_linea(archivo, "#{numero}. #{mensaje}")
          end)
      end
    end)
  end

  # ---------------------------------------------------------------
  # Construccion de los datos del problema
  # ---------------------------------------------------------------

  @doc """
  Funcion para construir el mapa con todos los datos del problema:
  - cuadricula: %{{fila, columna} => simbolo}
  - terrenos: %{simbolo => %Terreno{}}
  - lista_terrenos y transitables: en el orden de terrenos.csv
  - inicio y meta: posiciones de S y M
  - bateria, filas y columnas
  ## PARAMETRO
    - terrenos: lista de {linea, %Terreno{}}
    - filas: lista de {linea, [simbolos]} del edificio
    - bateria: presupuesto maximo de energia B

  ## EJEMPLO
    iex > problema = Rescate.construir_problema(terrenos, filas, 10)
    iex > problema.inicio
    {1, 1}
  """
  def construir_problema(terrenos, filas, bateria) do
    lista_terrenos = Enum.map(terrenos, fn {_linea, terreno} -> terreno end)
    mapa_terrenos = Map.new(lista_terrenos, fn terreno -> {terreno.simbolo, terreno} end)

    transitables =
      lista_terrenos
      |> Enum.filter(fn terreno -> terreno.transitable end)
      |> Enum.map(fn terreno -> terreno.simbolo end)

    # cuadrícula: %{{fila, columna} => simbolo}
    cuadricula =
      filas
      |> Enum.with_index()
      |> Enum.flat_map(fn {{_linea, simbolos}, fila} ->
        simbolos
        |> Enum.with_index()
        |> Enum.map(fn {simbolo, columna} -> {{fila, columna}, simbolo} end)
      end)
      |> Map.new()

    [{_linea, primera} | _resto] = filas

    %{
      cuadricula: cuadricula,
      terrenos: mapa_terrenos,
      lista_terrenos: lista_terrenos,
      transitables: transitables,
      inicio: buscar_posicion(cuadricula, @inicio),
      meta: buscar_posicion(cuadricula, @meta),
      bateria: bateria,
      filas: length(filas),
      columnas: length(primera)
    }
  end

  @doc """
  Funcion para buscar la posicion de un simbolo en la cuadricula
  ## PARAMETRO
    - cuadricula: mapa %{{fila, columna} => simbolo}
    - simbolo: simbolo que se busca (debe existir)

  ## EJEMPLO
    iex > Rescate.buscar_posicion(%{{1, 1} => "S", {1, 2} => "M"}, "M")
    {1, 2}
  """
  def buscar_posicion(cuadricula, simbolo) do
    {posicion, _simbolo} = Enum.find(cuadricula, fn {_posicion, s} -> s == simbolo end)
    posicion
  end

  @doc """
  Funcion para obtener el costo de entrar a una posicion. Devuelve
  {:ok, costo} o :no_transitable (paredes o posiciones fuera del edificio).
  Los costos vienen de terrenos.csv
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3
    - posicion: tupla {fila, columna}

  ## EJEMPLO
    iex > Rescate.costo_entrada(problema, {0, 0})
    :no_transitable
    iex > Rescate.costo_entrada(problema, {1, 2})
    {:ok, 1}
  """
  def costo_entrada(problema, posicion) do
    case Map.fetch(problema.cuadricula, posicion) do
      {:ok, simbolo} -> costo_de_terreno(Map.fetch!(problema.terrenos, simbolo))
      :error -> :no_transitable
    end
  end

  @doc """
  Funcion que, mediante pattern matching, rechaza los terrenos no transitables
  y devuelve el costo de los demas
  ## PARAMETRO
    - terreno: %Terreno{}

  ## EJEMPLO
    iex > Rescate.costo_de_terreno(%Terreno{transitable: false, costo: 0})
    :no_transitable
    iex > Rescate.costo_de_terreno(%Terreno{transitable: true, costo: 3})
    {:ok, 3}
  """
  def costo_de_terreno(%Terreno{transitable: false}), do: :no_transitable
  def costo_de_terreno(%Terreno{costo: costo}), do: {:ok, costo}

  @doc """
  Funcion para obtener las cuatro posiciones vecinas, en el orden fijo
  arriba, derecha, abajo, izquierda
  ## PARAMETRO
    - posicion: tupla {fila, columna}

  ## EJEMPLO
    iex > Rescate.vecinos({1, 1})
    [{0, 1}, {1, 2}, {2, 1}, {1, 0}]
  """
  def vecinos({fila, columna}) do
    Enum.map(@movimientos, fn {df, dc} -> {fila + df, columna + dc} end)
  end

  # ---------------------------------------------------------------
  # Stream infinito: relajacion de energia minima
  # ---------------------------------------------------------------

  @doc """
  Funcion que crea el Stream infinito de mapas de costo minimo conocido por
  posicion. Paso 0: solo S con costo 0. Cada paso siguiente se calcula
  a partir del anterior con relajar/2
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3

  ## EJEMPLO
    iex > Rescate.estados_de_energia(problema) |> Enum.take(2)
    [%{{1, 1} => 0}, %{{1, 1} => 0, {1, 2} => 1, {2, 1} => 1}]
  """
  def estados_de_energia(problema) do
    Stream.iterate(%{problema.inicio => 0}, fn estado -> relajar(problema, estado) end)
  end

  @doc """
  Funcion que calcula el siguiente estado: conserva los costos ya encontrados
  y actualiza cada posicion a partir del estado anterior
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3
    - estado: mapa %{posicion => costo minimo conocido}

  ## EJEMPLO
    iex > Rescate.relajar(problema, %{{1, 1} => 0})
    %{{1, 1} => 0, {1, 2} => 1, {2, 1} => 1}
  """
  def relajar(problema, estado) do
    problema.cuadricula
    |> Map.keys()
    |> Enum.reduce(estado, fn posicion, nuevo ->
      mejorar(problema, estado, nuevo, posicion)
    end)
  end

  @doc """
  Funcion que actualiza el costo de una posicion a partir de sus vecinos:
  costo del vecino + costo de entrada a la posicion. Se descartan los costos
  mayores que B y se conserva el menor
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3
    - estado: estado anterior (de donde se leen los costos de los vecinos)
    - nuevo: estado que se va construyendo
    - posicion: posicion que se actualiza

  ## EJEMPLO
    iex > Rescate.mejorar(problema, %{{1, 1} => 0}, %{{1, 1} => 0}, {1, 2})
    %{{1, 1} => 0, {1, 2} => 1}
  """
  def mejorar(problema, estado, nuevo, posicion) do
    case costo_entrada(problema, posicion) do
      :no_transitable ->
        nuevo

      {:ok, costo} ->
        candidatos =
          posicion
          |> vecinos()
          |> Enum.filter(fn vecino -> Map.has_key?(estado, vecino) end)
          |> Enum.map(fn vecino -> Map.fetch!(estado, vecino) + costo end)
          |> Enum.filter(fn total -> total <= problema.bateria end)

        case candidatos do
          [] ->
            nuevo

          _ ->
            mejor = Enum.min(candidatos)

            case Map.fetch(nuevo, posicion) do
              {:ok, actual} -> Map.put(nuevo, posicion, min(actual, mejor))
              :error -> Map.put(nuevo, posicion, mejor)
            end
        end
    end
  end

  @doc """
  Funcion que consume el Stream hasta el primer par de estados consecutivos
  iguales y devuelve el indice del primero de ese par
  ## PARAMETRO
    - estados: Stream infinito de estados

  ## EJEMPLO
    iex > Rescate.indice_de_estabilizacion(Stream.iterate(0, fn x -> min(x + 1, 3) end))
    3
  """
  def indice_de_estabilizacion(estados) do
    {_par, indice} =
      estados
      |> Stream.chunk_every(2, 1, :discard)
      |> Stream.with_index()
      |> Enum.find(fn {[anterior, siguiente], _indice} -> anterior == siguiente end)

    indice
  end

  @doc """
  Funcion para escribir expansion_energia.txt: los pasos distintos del Stream
  (posiciones ordenadas por fila y columna), el indice de estabilizacion y el
  costo minimo de la meta
  ## PARAMETRO
    - ruta: ruta del archivo de salida
    - problema: mapa creado con construir_problema/3
    - estados: Stream infinito de estados
    - indice: indice de estabilizacion
    - estado_final: estado en el indice de estabilizacion

  ## EJEMPLO
    iex > Rescate.escribir_expansion("salida/rescate/expansion_energia.txt", problema, estados, 5, estado_final)
  """
  def escribir_expansion(ruta, problema, estados, indice, estado_final) do
    Util.con_archivo(ruta, fn archivo ->
      Util.escribir_linea(archivo, "EXPANSIÓN DE ENERGÍA MÍNIMA (relajación)")
      Util.escribir_linea(archivo, "Presupuesto B = #{problema.bateria}")

      estados
      |> Stream.take(indice + 1)
      |> Stream.with_index()
      |> Enum.each(fn {estado, paso} -> escribir_paso(archivo, estado, paso) end)

      Util.escribir_linea(archivo, "")

      Util.escribir_linea(
        archivo,
        "Índice de estabilización: #{indice} (el estado #{indice + 1} es igual al estado #{indice})"
      )

      {fila, columna} = problema.meta

      case Map.fetch(estado_final, problema.meta) do
        {:ok, costo} ->
          Util.escribir_linea(archivo, "Meta {#{fila}, #{columna}}: costo mínimo #{costo}")

        :error ->
          Util.escribir_linea(
            archivo,
            "Meta {#{fila}, #{columna}}: sin costo alcanzable; se omite la enumeración"
          )
      end
    end)
  end

  @doc """
  Funcion para escribir un paso del Stream: sus posiciones ordenadas por
  fila y columna con su costo
  ## PARAMETRO
    - archivo: archivo abierto
    - estado: mapa %{posicion => costo}
    - paso: numero del paso

  ## EJEMPLO
    iex > Rescate.escribir_paso(archivo, %{{1, 1} => 0}, 0)
  """
  def escribir_paso(archivo, estado, paso) do
    Util.escribir_linea(archivo, "Paso #{paso}:")

    estado
    |> Map.to_list()
    |> Util2.ordenar(:asc, fn {posicion, _costo} -> posicion end)
    |> Enum.each(fn {{fila, columna}, costo} ->
      Util.escribir_linea(archivo, "  {#{fila}, #{columna}} = #{costo}")
    end)
  end

  # ---------------------------------------------------------------
  # Enumeracion recursiva de recorridos simples
  # ---------------------------------------------------------------

  @doc """
  Funcion recursiva que encuentra todos los recorridos simples desde una
  posicion hasta la meta sin superar B.
  - Caso base: se llego a la meta, se devuelve el recorrido
  - Caso recursivo: se prueba cada movimiento (arriba, derecha, abajo,
    izquierda) y se juntan los recorridos encontrados
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3
    - posicion: posicion actual
    - camino: posiciones visitadas (la mas reciente primero)
    - energia: energia consumida hasta ahora

  ## EJEMPLO
    iex > Rescate.explorar(problema, problema.inicio, [problema.inicio], 0)
    [%Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}, {1, 4}], energia: 5}, ...]
  """
  def explorar(problema, posicion, camino, energia) do
    case posicion == problema.meta do
      true ->
        [%Recorrido{posiciones: Enum.reverse(camino), energia: energia}]

      false ->
        Enum.flat_map(@movimientos, fn movimiento ->
          avanzar(problema, posicion, movimiento, camino, energia)
        end)
    end
  end

  @doc """
  Funcion que intenta dar un movimiento. Se rechaza si la casilla no es
  transitable, si supera B o si ya fue visitada; si no, continua la
  exploracion recursivamente desde la nueva posicion
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3
    - posicion: posicion actual {fila, columna}
    - movimiento: tupla {delta_fila, delta_columna}
    - camino: posiciones visitadas (la mas reciente primero)
    - energia: energia consumida hasta ahora

  ## EJEMPLO
    iex > Rescate.avanzar(problema, {1, 1}, {-1, 0}, [{1, 1}], 0)
    []
  """
  def avanzar(problema, {fila, columna}, {df, dc}, camino, energia) do
    siguiente = {fila + df, columna + dc}

    case costo_entrada(problema, siguiente) do
      :no_transitable ->
        []

      {:ok, costo} ->
        nueva_energia = energia + costo

        case nueva_energia <= problema.bateria and not Util.miembro?(camino, siguiente) do
          true -> explorar(problema, siguiente, [siguiente | camino], nueva_energia)
          false -> []
        end
    end
  end

  # ---------------------------------------------------------------
  # Salidas de texto
  # ---------------------------------------------------------------

  @doc """
  Funcion para obtener el numero de movimientos de un recorrido
  ## PARAMETRO
    - recorrido: %Recorrido{}

  ## EJEMPLO
    iex > Rescate.movimientos(%Recorrido{posiciones: [{1, 1}, {1, 2}, {1, 3}], energia: 4})
    2
  """
  def movimientos(%Recorrido{posiciones: posiciones}), do: length(posiciones) - 1

  @doc """
  Funcion para convertir una lista de posiciones en texto
  ## PARAMETRO
    - posiciones: lista de tuplas {fila, columna}

  ## EJEMPLO
    iex > Rescate.texto_posiciones([{1, 1}, {1, 2}])
    "(1,1) -> (1,2)"
  """
  def texto_posiciones(posiciones) do
    posiciones
    |> Enum.map(fn {fila, columna} -> "(#{fila},#{columna})" end)
    |> Enum.join(" -> ")
  end

  @doc """
  Funcion para escribir recorridos_rescate.csv, una fila por recorrido, con
  separador ;
  ## PARAMETRO
    - ruta: ruta del archivo de salida
    - numerados: lista de {id, %Recorrido{}}

  ## EJEMPLO
    iex > Rescate.escribir_csv("salida/rescate/recorridos_rescate.csv", numerados)
  """
  def escribir_csv(ruta, numerados) do
    Util.con_archivo(ruta, fn archivo ->
      Util.escribir_linea(archivo, "id;movimientos;energia;posiciones")

      Enum.each(numerados, fn {id, recorrido} ->
        Util.escribir_linea(
          archivo,
          "#{id};#{movimientos(recorrido)};#{recorrido.energia};" <>
            texto_posiciones(recorrido.posiciones)
        )
      end)
    end)
  end

  @doc """
  Funcion para armar la linea de un recorrido dentro del resumen
  ## PARAMETRO
    - numerado: tupla {id, %Recorrido{}}

  ## EJEMPLO
    iex > Rescate.linea_recorrido({1, %Recorrido{posiciones: [{1, 1}, {1, 2}], energia: 1}})
    "  Recorrido 1: 1 movimientos, energía 1, (1,1) -> (1,2)"
  """
  def linea_recorrido({id, recorrido}) do
    "  Recorrido #{id}: #{movimientos(recorrido)} movimientos, energía #{recorrido.energia}, " <>
      texto_posiciones(recorrido.posiciones)
  end

  @doc """
  Funcion para construir las lineas del resumen: total de recorridos,
  recorridos con menos movimientos y recorridos con menor consumo de energia
  (conservando los empates). Si no hay recorridos lo indica
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3
    - numerados: lista de {id, %Recorrido{}}

  ## EJEMPLO
    iex > Rescate.construir_resumen(problema, [])
    ["RESUMEN DEL ROBOT DE RESCATE", "Presupuesto de energía (B): 10", "Total de recorridos válidos: 0", "No existe un recorrido válido de S a M sin superar B."]
  """
  def construir_resumen(problema, []) do
    [
      "RESUMEN DEL ROBOT DE RESCATE",
      "Presupuesto de energía (B): #{problema.bateria}",
      "Total de recorridos válidos: 0",
      "No existe un recorrido válido de S a M sin superar B."
    ]
  end

  def construir_resumen(problema, numerados) do
    minimo_movimientos =
      numerados |> Enum.map(fn {_id, r} -> movimientos(r) end) |> Enum.min()

    minima_energia =
      numerados |> Enum.map(fn {_id, r} -> r.energia end) |> Enum.min()

    con_menos_movimientos =
      Enum.filter(numerados, fn {_id, r} -> movimientos(r) == minimo_movimientos end)

    con_menor_energia =
      Enum.filter(numerados, fn {_id, r} -> r.energia == minima_energia end)

    [
      "RESUMEN DEL ROBOT DE RESCATE",
      "Presupuesto de energía (B): #{problema.bateria}",
      "Total de recorridos válidos: #{length(numerados)}",
      "Recorridos con menos movimientos (#{minimo_movimientos} movimientos): " <>
        "#{length(con_menos_movimientos)}"
    ] ++
      Enum.map(con_menos_movimientos, &linea_recorrido/1) ++
      [
        "Recorridos con menor consumo de energía (#{minima_energia}): " <>
          "#{length(con_menor_energia)}"
      ] ++
      Enum.map(con_menor_energia, &linea_recorrido/1)
  end

  @doc """
  Funcion para escribir una lista de lineas en un archivo de texto
  ## PARAMETRO
    - ruta: ruta del archivo de salida
    - lineas: lista de textos, uno por linea

  ## EJEMPLO
    iex > Rescate.escribir_resumen("salida/rescate/resumen_rescate.txt", ["linea 1", "linea 2"])
  """
  def escribir_resumen(ruta, lineas) do
    Util.con_archivo(ruta, fn archivo ->
      Enum.each(lineas, fn linea -> Util.escribir_linea(archivo, linea) end)
    end)
  end

  # ---------------------------------------------------------------
  # SVG (se escribe por fragmentos, un elemento por linea)
  # ---------------------------------------------------------------

  @doc """
  Funcion para dibujar el edificio en ruta_optima.svg con casillas de 40 x 40
  pixeles, colores por tipo de terreno, la ruta de menor energia remarcada
  con segmentos y marcadores, y una leyenda. Si no hay ruta, la leyenda dice
  "sin recorrido"
  ## PARAMETRO
    - ruta: ruta del archivo SVG
    - problema: mapa creado con construir_problema/3
    - mejor: tupla {id, %Recorrido{}} del recorrido de menor energia, o nil

  ## EJEMPLO
    iex > Rescate.escribir_svg("salida/rescate/ruta_optima.svg", problema, nil)
  """
  def escribir_svg(ruta, problema, mejor) do
    ancho = max(problema.columnas * @lado, 360)
    alto_mapa = problema.filas * @lado
    alto = alto_mapa + 20 + (length(problema.lista_terrenos) + 1) * 26 + 10

    Util.con_archivo(ruta, fn archivo ->
      Util.escribir_linea(archivo, ~s(<?xml version="1.0" encoding="UTF-8"?>))

      Util.escribir_linea(
        archivo,
        ~s(<svg xmlns="http://www.w3.org/2000/svg" width="#{ancho}" height="#{alto}" viewBox="0 0 #{ancho} #{alto}">)
      )

      Util.escribir_linea(archivo, ~s(<rect width="#{ancho}" height="#{alto}" fill="white"/>))

      problema.cuadricula
      |> Map.keys()
      |> Enum.sort()
      |> Enum.each(fn posicion -> dibujar_casilla(archivo, problema, posicion) end)

      dibujar_ruta(archivo, mejor)
      dibujar_leyenda(archivo, problema, mejor)

      Util.escribir_linea(archivo, "</svg>")
    end)
  end

  @doc """
  Funcion para dibujar una casilla: un cuadrado del color de su terreno con
  su simbolo (escapado para XML)
  ## PARAMETRO
    - archivo: archivo SVG abierto
    - problema: mapa creado con construir_problema/3
    - posicion: tupla {fila, columna}

  ## EJEMPLO
    iex > Rescate.dibujar_casilla(archivo, problema, {1, 1})
  """
  def dibujar_casilla(archivo, problema, {fila, columna}) do
    simbolo = Map.fetch!(problema.cuadricula, {fila, columna})
    terreno = Map.fetch!(problema.terrenos, simbolo)
    x = columna * @lado
    y = fila * @lado

    Util.escribir_linea(
      archivo,
      ~s(<rect x="#{x}" y="#{y}" width="#{@lado}" height="#{@lado}" fill="#{color_terreno(problema, terreno)}" stroke="#999999" stroke-width="1"/>)
    )

    Util.escribir_linea(
      archivo,
      ~s(<text x="#{x + 20}" y="#{y + 25}" text-anchor="middle" font-family="sans-serif" font-size="16" fill="#222222">#{Util.escape_xml(simbolo)}</text>)
    )
  end

  @doc """
  Funcion para obtener el color de un terreno. Los no transitables van en
  gris (pattern matching); los transitables toman un color de la paleta segun
  su orden en terrenos.csv
  ## PARAMETRO
    - problema: mapa creado con construir_problema/3
    - terreno: %Terreno{}

  ## EJEMPLO
    iex > Rescate.color_terreno(problema, %Terreno{simbolo: "X", transitable: false})
    "#9e9e9e"
  """
  def color_terreno(_problema, %Terreno{transitable: false}), do: @color_pared

  def color_terreno(problema, %Terreno{simbolo: simbolo}) do
    indice = Enum.find_index(problema.transitables, fn s -> s == simbolo end)
    Enum.at(@paleta, rem(indice, length(@paleta)))
  end

  @doc """
  Funcion para obtener el centro de una casilla en pixeles {x, y}
  ## PARAMETRO
    - posicion: tupla {fila, columna}

  ## EJEMPLO
    iex > Rescate.centro({1, 2})
    {100, 60}
  """
  def centro({fila, columna}) do
    {columna * @lado + div(@lado, 2), fila * @lado + div(@lado, 2)}
  end

  @doc """
  Funcion para dibujar la ruta de menor energia: segmentos entre las
  posiciones y marcadores en el inicio y la meta. Si no hay ruta no dibuja nada
  ## PARAMETRO
    - archivo: archivo SVG abierto
    - mejor: tupla {id, %Recorrido{}} o nil

  ## EJEMPLO
    iex > Rescate.dibujar_ruta(archivo, nil)
    :ok
  """
  def dibujar_ruta(_archivo, nil), do: :ok

  def dibujar_ruta(archivo, {_id, %Recorrido{posiciones: posiciones}}) do
    dibujar_segmentos(archivo, posiciones)
    dibujar_marcador(archivo, hd(posiciones))
    dibujar_marcador(archivo, List.last(posiciones))
  end

  @doc """
  Funcion recursiva para dibujar un segmento entre cada par de posiciones
  consecutivas de la ruta
  ## PARAMETRO
    - archivo: archivo SVG abierto
    - posiciones: posiciones de la ruta que faltan por dibujar

  ## EJEMPLO
    iex > Rescate.dibujar_segmentos(archivo, [{1, 1}, {1, 2}, {1, 3}])
  """
  def dibujar_segmentos(_archivo, [_ultima]), do: :ok

  def dibujar_segmentos(archivo, [primera, segunda | resto]) do
    {x1, y1} = centro(primera)
    {x2, y2} = centro(segunda)

    Util.escribir_linea(
      archivo,
      ~s(<line x1="#{x1}" y1="#{y1}" x2="#{x2}" y2="#{y2}" stroke="#{@color_ruta}" stroke-width="5" stroke-linecap="round"/>)
    )

    dibujar_segmentos(archivo, [segunda | resto])
  end

  @doc """
  Funcion para dibujar un marcador (circulo) en una posicion
  ## PARAMETRO
    - archivo: archivo SVG abierto
    - posicion: tupla {fila, columna}

  ## EJEMPLO
    iex > Rescate.dibujar_marcador(archivo, {1, 1})
  """
  def dibujar_marcador(archivo, posicion) do
    {x, y} = centro(posicion)

    Util.escribir_linea(
      archivo,
      ~s(<circle cx="#{x}" cy="#{y}" r="8" fill="#{@color_ruta}" stroke="white" stroke-width="2"/>)
    )
  end

  @doc """
  Funcion para describir un terreno en la leyenda
  ## PARAMETRO
    - terreno: %Terreno{}

  ## EJEMPLO
    iex > Rescate.descripcion_terreno(%Terreno{simbolo: "L", nombre: "lodo", transitable: true, costo: 3})
    "L = lodo (costo 3)"
  """
  def descripcion_terreno(%Terreno{transitable: false} = terreno) do
    "#{terreno.simbolo} = #{terreno.nombre} (no transitable)"
  end

  def descripcion_terreno(%Terreno{} = terreno) do
    "#{terreno.simbolo} = #{terreno.nombre} (costo #{terreno.costo})"
  end

  @doc """
  Funcion para dibujar la leyenda: un cuadro de color por cada terreno y una
  linea final que describe la ruta (o dice "sin recorrido")
  ## PARAMETRO
    - archivo: archivo SVG abierto
    - problema: mapa creado con construir_problema/3
    - mejor: tupla {id, %Recorrido{}} o nil

  ## EJEMPLO
    iex > Rescate.dibujar_leyenda(archivo, problema, nil)
  """
  def dibujar_leyenda(archivo, problema, mejor) do
    y_inicial = problema.filas * @lado + 20

    problema.lista_terrenos
    |> Enum.with_index()
    |> Enum.each(fn {terreno, indice} ->
      y = y_inicial + indice * 26
      texto = Util.escape_xml(descripcion_terreno(terreno))

      Util.escribir_linea(
        archivo,
        ~s(<rect x="10" y="#{y}" width="20" height="20" fill="#{color_terreno(problema, terreno)}" stroke="#999999"/>)
      )

      Util.escribir_linea(
        archivo,
        ~s(<text x="40" y="#{y + 15}" font-family="sans-serif" font-size="14" fill="#222222">#{texto}</text>)
      )
    end)

    y_ruta = y_inicial + length(problema.lista_terrenos) * 26
    dibujar_leyenda_ruta(archivo, y_ruta, mejor)
  end

  @doc """
  Funcion para dibujar la ultima linea de la leyenda, la de la ruta
  ## PARAMETRO
    - archivo: archivo SVG abierto
    - y: posicion vertical de la linea
    - mejor: tupla {id, %Recorrido{}} o nil (nil escribe "sin recorrido")

  ## EJEMPLO
    iex > Rescate.dibujar_leyenda_ruta(archivo, 300, nil)
  """
  def dibujar_leyenda_ruta(archivo, y, nil) do
    Util.escribir_linea(
      archivo,
      ~s(<text x="10" y="#{y + 15}" font-family="sans-serif" font-size="14" fill="#222222">Ruta: sin recorrido</text>)
    )
  end

  def dibujar_leyenda_ruta(archivo, y, {id, recorrido}) do
    texto =
      Util.escape_xml(
        "Ruta de menor energía (recorrido #{id}): #{recorrido.energia} de energía, " <>
          "#{movimientos(recorrido)} movimientos"
      )

    Util.escribir_linea(
      archivo,
      ~s(<line x1="10" y1="#{y + 10}" x2="30" y2="#{y + 10}" stroke="#{@color_ruta}" stroke-width="5" stroke-linecap="round"/>)
    )

    Util.escribir_linea(
      archivo,
      ~s(<text x="40" y="#{y + 15}" font-family="sans-serif" font-size="14" fill="#222222">#{texto}</text>)
    )
  end
end

# Se pueden indicar la carpeta de entrada y la de salida al ejecutar:
#   elixir rescate.exs entrada/rescate salida/rescate
case System.argv() do
  [entrada, salida] -> Rescate.ejecutar(entrada, salida)
  _ -> Rescate.ejecutar()
end
