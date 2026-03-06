defmodule BlockScoutWeb.GraphQL.Schema.TypesTest do
  use ExUnit.Case, async: true

  alias Explorer.Chain.SmartContract

  test "language enum matches supported smart contract languages" do
    graphql_languages =
      Absinthe.Schema.lookup_type(BlockScoutWeb.GraphQL.Schema, :language).values
      |> Map.keys()
      |> Enum.map(&to_string/1)
      |> Enum.sort()

    assert graphql_languages == Enum.sort(SmartContract.language_strings())
  end
end
