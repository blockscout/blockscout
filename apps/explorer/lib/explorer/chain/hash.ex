defmodule Explorer.Chain.Hash do
  @moduledoc """
  Hash used throughout Ethereum chains.
  """

  @typedoc """
  [KECCAK-256](https://en.wikipedia.org/wiki/SHA-3) hash as a string.
  """
  @type t :: String.t()
end
