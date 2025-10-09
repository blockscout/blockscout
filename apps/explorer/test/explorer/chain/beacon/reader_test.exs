defmodule Explorer.Chain.Beacon.ReaderTest do
  use Explorer.DataCase

  alias Explorer.Chain.Beacon.Reader

  if Application.compile_env(:explorer, :chain_type) == :ethereum do
    doctest Reader
  end
end
