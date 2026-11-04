defmodule Tarea do
  @enforce_keys [:id, :duracion, :plazo]
  defstruct [:id, :duracion, :plazo, dependencias: []]
end
