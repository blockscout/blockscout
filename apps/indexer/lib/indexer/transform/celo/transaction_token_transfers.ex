defmodule Indexer.Transform.Celo.TransactionTokenTransfers do
  @moduledoc """
  Helper functions for generating ERC20 token transfers from native Celo coin
  transfers.
  """
  require Logger

  alias Explorer.Chain.Cache.CeloCoreContracts

  def parse(transactions, logs) do
    if Application.get_env(:explorer, :chain_type) == "celo" do
      first_artificial_log_index = length(logs)
      core_contract_addresses = CeloCoreContracts.get_contract_addresses()
      celo_native_token_address_hash = core_contract_addresses.celo_token

      token_type = "ERC-20"

      token_transfers =
        transactions
        |> Enum.filter(fn a -> a.value > 0 end)
        |> Enum.with_index(first_artificial_log_index)
        |> Enum.map(fn {tx, artificial_log_index} ->
          to_address_hash = tx.to_address_hash || tx.created_contract_address_hash

          %{
            amount: Decimal.new(tx.value),
            block_hash: tx.block_hash,
            block_number: tx.block_number,
            from_address_hash: tx.from_address_hash,
            log_index: artificial_log_index,
            to_address_hash: to_address_hash,
            token_contract_address_hash: celo_native_token_address_hash,
            token_ids: nil,
            token_type: token_type,
            transaction_hash: tx.hash
          }
        end)

      Logger.info("Found #{length(token_transfers)} Celo token transfers.")

      %{
        token_transfers: token_transfers,
        tokens:
          if Enum.empty?(token_transfers) do
            []
          else
            [
              %{
                contract_address_hash: celo_native_token_address_hash,
                type: token_type
              }
            ]
          end
      }
    else
      %{token_transfers: [], tokens: []}
    end
  end
end
