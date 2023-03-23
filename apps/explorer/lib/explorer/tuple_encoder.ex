defmodule TupleEncoder do
  alias Jason.Encoder

  defimpl Encoder, for: Tuple do
    def encode(value, opts) when is_tuple(value) do
      value
      |> Tuple.to_list()
      |> Jason.Encode.list(opts)
    end
  end
end
