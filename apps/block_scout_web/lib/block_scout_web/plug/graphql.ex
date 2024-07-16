defmodule BlockScoutWeb.Plug.GraphQL do
  @moduledoc """
  Default query for GraphiQL interface.
  """

  def default_query do
    transaction_hash = Application.get_env(:block_scout_web, Api.GraphQL)[:default_transaction_hash]

    "{transaction(hash: \"#{transaction_hash}\") { hash, blockNumber, value, gasUsed }}"
  end
end
