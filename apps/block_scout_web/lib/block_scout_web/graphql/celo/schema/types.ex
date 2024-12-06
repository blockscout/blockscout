defmodule BlockScoutWeb.GraphQL.Celo.Schema.Types do
  @moduledoc false

  use Absinthe.Schema.Notation
  use Absinthe.Relay.Schema.Notation, :modern

  alias BlockScoutWeb.GraphQL.Celo.Resolvers.TokenTransfer

  @desc """
  Represents a CELO or usd token transfer between addresses.
  """
  node object(:celo_transfer, id_fetcher: &celo_transfer_id_fetcher/2) do
    field(:value, :decimal)
    field(:token, :string)
    field(:token_address, :string)
    field(:token_type, :string)
    field(:token_id, :decimal)
    field(:block_number, :integer)
    field(:from_address_hash, :address_hash)
    field(:to_address_hash, :address_hash)
    field(:transaction_hash, :full_hash)

    field(:log_index, :integer)

    field(:gas_price, :wei)
    field(:gas_used, :decimal)
    field(:input, :string)
    field(:timestamp, :datetime)
    field(:comment, :string)

    field(:to_account_hash, :address_hash)
    field(:from_account_hash, :address_hash)
  end

  @desc """
  Represents a CELO token transfer between addresses.
  """
  node object(:transfer_transaction, id_fetcher: &transfer_transaction_id_fetcher/2) do
    field(:gateway_fee_recipient, :address_hash)
    field(:gateway_fee, :address_hash)
    field(:fee_currency, :address_hash)
    field(:fee_token, :string)
    field(:address_hash, :address_hash)
    field(:transaction_hash, :full_hash)
    field(:block_number, :integer)
    field(:gas_price, :wei)
    field(:gas_used, :decimal)
    field(:input, :string)
    field(:timestamp, :datetime)

    connection field(:token_transfer, node_type: :celo_transfer) do
      arg(:count, :integer)
      resolve(&TokenTransfer.get_by/3)

      complexity(fn
        %{first: first}, child_complexity ->
          first * child_complexity

        %{last: last}, child_complexity ->
          last * child_complexity
      end)
    end
  end

  connection(node_type: :transfer_transaction)
  connection(node_type: :celo_transfer)

  defp transfer_transaction_id_fetcher(
         %{transaction_hash: transaction_hash, address_hash: address_hash},
         _
       ) do
    Jason.encode!(%{
      transaction_hash: to_string(transaction_hash),
      address_hash: to_string(address_hash)
    })
  end

  defp celo_transfer_id_fetcher(
         %{transaction_hash: transaction_hash, log_index: log_index},
         _
       ) do
    Jason.encode!(%{
      transaction_hash: to_string(transaction_hash),
      log_index: log_index
    })
  end
end
