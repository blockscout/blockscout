defmodule BlockScoutWeb.GraphQL.Celo.QueryFields do
  @moduledoc """
  Query fields for the CELO schema.
  """

  alias BlockScoutWeb.GraphQL.Celo.Resolvers.TokenTransferTx

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema, :modern

  defmacro generate do
    quote do
      @desc "Gets token transfer transactions."
      connection field(:token_transfer_txs, node_type: :transfer_tx) do
        arg(:address_hash, :address_hash)
        arg(:count, :integer)

        resolve(&TokenTransferTx.get_by/3)

        complexity(fn
          %{first: first}, child_complexity -> first * child_complexity
          %{last: last}, child_complexity -> last * child_complexity
          %{}, _child_complexity -> 0
        end)
      end
    end
  end
end
