defmodule Explorer.IndexerTest do
  use Explorer.DataCase, async: true

  alias Explorer.Indexer

  import Explorer.Factory

  doctest Indexer
end
