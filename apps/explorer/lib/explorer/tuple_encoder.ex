# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule TupleEncoder do
  @moduledoc """
    Implementation of JSON.Encoder for Tuple
  """

  defimpl JSON.Encoder, for: Tuple do
    def encode(value, encoder) when is_tuple(value) do
      value
      |> Tuple.to_list()
      |> JSON.Encoder.encode(encoder)
    end
  end
end
