defmodule Plan do
  @enforce_keys [:orden, :finalizaciones, :penalizacion, :duracion_total]
  defstruct [:orden, :finalizaciones, :penalizacion, :duracion_total]
end
