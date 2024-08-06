defmodule Indexer.Transform.Celo.TransactionTokenTransfers do
  @moduledoc """
  Helper functions for generating ERC20 token transfers from native Celo coin
  transfers.

  CELO has a feature referred to as "token duality", where the native chain
  asset (CELO) can be used as both a native chain currency and as an ERC-20
  token. Unfortunately native chain asset transfers do not emit ERC-20 transfer
  events, which requires the artificial creation of entries in the
  `token_transfers` table.
  """
  require Logger

  import Indexer.Transform.TokenTransfers,
    only: [
      filter_tokens_for_supply_update: 1
    ]

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.Hash
  alias Indexer.Fetcher.TokenTotalSupplyUpdater
  @token_type "ERC-20"
  @transaction_buffer_size 20_000

  @doc """
  In order to avoid conflicts with real token transfers, for native token
  transfers we put a negative `log_index`.

  Each transaction within the block is assigned a so-called _buffer_ of
  #{@transaction_buffer_size} entries. Thus, according to the formula,
  transactions with indices 0, 1, 2 would have log indices -20000, -40000,
  -60000.

  The spare intervals between the log indices (0..-19_999, -20_001..-39_999,
  -40_001..59_999) are reserved for native token transfers fetched from
  internal transactions.
  """
  @spec parse_transactions([
          %{
            required(:value) => non_neg_integer(),
            optional(:to_address_hash) => Hash.Address.t() | nil,
            optional(:created_contract_address_hash) => Hash.Address.t() | nil
          }
        ]) :: %{
          token_transfers: list(),
          tokens: list()
        }
  def parse_transactions(transactions) do
    token_transfers =
      if Application.get_env(:explorer, :chain_type) == :celo do
        transactions
        |> Enum.filter(fn tx -> tx.value > 0 end)
        |> Enum.map(fn tx ->
          to_address_hash = Map.get(tx, :to_address_hash) || Map.get(tx, :created_contract_address_hash)
          log_index = -1 * (tx.index + 1) * @transaction_buffer_size
          {:ok, celo_token_address} = CeloCoreContracts.get_address(:celo_token, tx.block_number)

          %{
            amount: Decimal.new(tx.value),
            block_hash: tx.block_hash,
            block_number: tx.block_number,
            from_address_hash: tx.from_address_hash,
            log_index: log_index,
            to_address_hash: to_address_hash,
            token_contract_address_hash: celo_token_address,
            token_ids: nil,
            token_type: @token_type,
            transaction_hash: tx.hash
          }
        end)
        |> tap(&Logger.debug("Found #{length(&1)} Celo token transfers."))
      else
        []
      end

    token_transfers
    |> filter_tokens_for_supply_update()
    |> TokenTotalSupplyUpdater.add_tokens()

    %{
      token_transfers: token_transfers,
      tokens: to_tokens(token_transfers)
    }
  end

  def parse_internal_transactions(internal_transactions, block_number_to_block_hash) do
    token_transfers =
      internal_transactions
      |> Enum.filter(fn itx ->
        itx.value > 0 &&
          itx.index > 0 &&
          not Map.has_key?(itx, :error) &&
          (not Map.has_key?(itx, :call_type) || itx.call_type != "delegatecall")
      end)
      |> Enum.map(fn itx ->
        to_address_hash = Map.get(itx, :to_address_hash) || Map.get(itx, :created_contract_address_hash)
        log_index = -1 * (itx.transaction_index * @transaction_buffer_size + itx.index)
        {:ok, celo_token_address} = CeloCoreContracts.get_address(:celo_token, itx.block_number)

        %{
          amount: Decimal.new(itx.value),
          block_hash: block_number_to_block_hash[itx.block_number],
          block_number: itx.block_number,
          from_address_hash: itx.from_address_hash,
          log_index: log_index,
          to_address_hash: to_address_hash,
          token_contract_address_hash: celo_token_address,
          token_ids: nil,
          token_type: @token_type,
          transaction_hash: itx.transaction_hash
        }
      end)

    Logger.debug("Found #{length(token_transfers)} Celo token transfers from internal transactions.")

    token_transfers
    |> filter_tokens_for_supply_update()
    |> TokenTotalSupplyUpdater.add_tokens()

    %{
      token_transfers: token_transfers,
      tokens: to_tokens(token_transfers)
    }
  end

  defp to_tokens([]), do: []

  defp to_tokens(token_transfers) do
    token_transfers
    |> Enum.map(
      &%{
        contract_address_hash: &1.token_contract_address_hash,
        type: @token_type
      }
    )
    |> Enum.uniq()
  end
end
