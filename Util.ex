defmodule Util do
  @moduledoc """
  Modulo con funciones utiles que se reutilizan
  - Autor: Eric Santiago Correa Alzate
  - fecha: 08/09/2026
  - licencia: GNU GPL v3
  """

  @doc """
  Funcion para mostrar mensaje
  ## PARAMETRO
    - mensaje: texto que se le presenta al ususario

  ## EJEMPLO
    iex > Util.mostrar_mensaje("Hola Mundo")

    - o puede usar

    "Hola Mundo"
    |> Util.mostrar_mensaje()
  """
  def mostrar_mensaje(mensaje) do
    mensaje
    |> IO.puts()
  end

  @doc """
  Funcion para ingresar datos desde el teclado
  ## PARAMETRO
    - mensaje: texto en el que se le solicita algo al ususario
    - atomo: identifica el tipo de dato.
            :texto para ingresar una cadena
            :entero para ingresar un valor entero

  ## EJEMPLO
    iex > Util.ingresar("Ingrese el nombre de su personaje: ", :texto)
    iex > Util.ingresar("Ingrese el nivel de su personaje: ", :entero)

    - o puede usar

    "Ingrese el nombre de su personaje: "
    |> Util.ingresar(:texto)

    "Ingrese el nivel de su personaje: "
    |> Util.ingresar(:entero)
  """
  def ingresar(mensaje, :texto) do
    mensaje
    |> IO.gets()
    |> String.trim()
  end

  def ingresar(mensaje, :entero) do
    ingresar(
      mensaje,
      &String.to_integer/1,
      :entero
    )
  end

  def ingresar(mensaje, :real) do
    ingresar(
      mensaje,
      &String.to_float/1,
      :real
    )
  end

  defp ingresar(mensaje, parser, tipo_dato) do
    try do
      mensaje
      |> ingresar(:texto)
      |> parser.()
    rescue
      ArgumentError ->
        "Error, se espera que ingrese un número #{tipo_dato}\n"
        |> mostrar_error()

        mensaje
        |> ingresar(parser, tipo_dato)
    end
  end

  @doc """
  Funcion para calcular una devuelta
  ## PARAMETRO
    - valor_pago:


    - valor_total:

  ## EJEMPLO
    iex > Util.mostrar_error("ERROR...")

    - o puede usar

    "ERROR..."
    |> Util.mostrar_error()
  """

  def calcular_devuelta(valor_pago, valor_total) do
    valor_pago - valor_total
  end

  @doc """
  Funcion para mostrar error
  ## PARAMETRO
    - mensaje: texto que se le presenta al ususario

  ## EJEMPLO
    iex > Util.mostrar_error("ERROR...")

    - o puede usar

    "ERROR..."
    |> Util.mostrar_error()
  """

  def mostrar_error(mensaje) do
    IO.puts(:standard_error, mensaje)
  end

  @doc """
  Funcion para leer un archivo de texto linea por linea (perezoso).
  Devuelve un Stream de tuplas {numero_de_linea_fisica, texto}, sin lineas
  en blanco ni comentarios (primer caracter no blanco = #).
  ## PARAMETRO
    - ruta: ruta del archivo que se va a leer

  ## EJEMPLO
    iex > Util.registros("entrada/tareas/tareas.csv") |> Enum.to_list()

    - o puede usar

    "entrada/tareas/tareas.csv"
    |> Util.registros()
    |> Enum.to_list()
  """
  def registros(ruta) do
    ruta
    |> File.stream!()
    |> Stream.with_index(1)
    |> Stream.map(fn {linea, n} -> {n, String.trim(linea)} end)
    |> Stream.reject(fn {_n, texto} ->
      texto == "" or String.starts_with?(texto, "#")
    end)
  end

  @doc """
  Funcion para crear (o reemplazar) un archivo de salida y escribir en el
  de forma progresiva. El archivo se cierra siempre al terminar.
  ## PARAMETRO
    - ruta: ruta del archivo de salida (crea las carpetas si no existen)
    - escribir: funcion que recibe el archivo abierto y escribe en el

  ## EJEMPLO
    iex > Util.con_archivo("salida/prueba.txt", fn f ->
    ...     Util.escribir_linea(f, "Hola")
    ...   end)
  """
  def con_archivo(ruta, escribir) do
    File.mkdir_p!(Path.dirname(ruta))
    archivo = File.open!(ruta, [:write, :utf8])

    try do
      escribir.(archivo)
    after
      File.close(archivo)
    end
  end

  @doc """
  Funcion para escribir una linea (con salto de linea) en un archivo abierto
  con Util.con_archivo/2
  ## PARAMETRO
    - archivo: archivo abierto
    - texto: texto de la linea

  ## EJEMPLO
    iex > Util.escribir_linea(archivo, "id;orden;duracion_total;penalizacion")
  """
  def escribir_linea(archivo, texto) do
    IO.write(archivo, texto <> "\n")
  end

  @doc """
  Funcion para escapar texto que va dentro de un SVG (XML)
  ## PARAMETRO
    - texto: texto original

  ## EJEMPLO
    iex > Util.escape_xml("A & B < C")
    "A &amp; B &lt; C"
  """
  def escape_xml(texto) do
    texto
    |> String.replace("&", "&amp;")
    |> String.replace("<", "&lt;")
    |> String.replace(">", "&gt;")
    |> String.replace("\"", "&quot;")
    |> String.replace("'", "&apos;")
  end

  @doc """
  Funcion recursiva para saber si un elemento esta en una lista.
  Se usa en las validaciones, donde no se permite Enum ni `in`.
  ## PARAMETRO
    - lista: lista donde se busca
    - elemento: valor a buscar

  ## EJEMPLO
    iex > Util.miembro?(["A", "B"], "B")
    true
  """
  def miembro?([], _elemento), do: false
  def miembro?([elemento | _], elemento), do: true
  def miembro?([_ | resto], elemento), do: miembro?(resto, elemento)
end
