defmodule TupleEncoder do
  @moduledoc """
    Implementation of Jason.Encoder for Tuple
  """
  alias Jason.{Encode, Encoder}

  defimpl Encoder, for: Tuple do
    def encode(value, opts) when is_tuple(value) do
      value
      |> Tuple.to_list()
      |> Encode.list(opts)
    end
  end
end
