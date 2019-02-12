defmodule BlockScoutWeb.Plug.GraphQL do
  @moduledoc """
  Default query for GraphiQL interface.
  """
  @default_transaction_hash "0x69e3923eef50eada197c3336d546936d0c994211492c9f947a24c02827568f9f"

  def default_query do
    transaction_hash = System.get_env("GRAPHIQL_TRANSACTION") || @default_transaction_hash

    "{transaction(hash: \"#{transaction_hash}\") { hash, blockNumber, value, gasUsed }}"
  end
end
