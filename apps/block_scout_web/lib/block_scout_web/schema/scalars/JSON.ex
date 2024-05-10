defmodule BlockScoutWeb.Schema.Scalars.JSON do
  @moduledoc """
  The JSON scalar type allows arbitrary JSON values to be passed in and out.
  """
  use Absinthe.Schema.Notation

  @desc """
  The `JSON` scalar type represents arbitrary JSON string data, represented as UTF-8
  character sequences. The JSON type is most often used to represent a free-form
  human-readable JSON string.
  """
  scalar :json do
    parse(&decode/1)
    serialize(&encode/1)
  end

  defp decode(%Absinthe.Blueprint.Input.String{value: value}) do
    case Jason.decode(value) do
      {:ok, result} -> {:ok, result}
      _ -> :error
    end
  end

  defp decode(%Absinthe.Blueprint.Input.Null{}) do
    {:ok, nil}
  end

  defp decode(_) do
    :error
  end

  defp encode(value), do: Jason.encode!(value)
end
