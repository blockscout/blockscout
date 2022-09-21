defmodule BlockScoutWeb.AddressEpochTransactionController do
  @moduledoc """
    Manages the displaying of information about epoch transactions as they relate to addresses
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.{AccessHelpers, Controller, EpochTransactionView}
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.{CeloAccountEpoch, CeloElectionRewards, Wei}
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      paging_options_keyword = paging_options(params)
      %Explorer.PagingOptions{page_size: page_size} = Keyword.get(paging_options_keyword, :paging_options)
      epoch_transactions = get_rewards(address, Map.put(params, "page_size", page_size))
      {epoch_transactions, next_page} = split_list_by_page(epoch_transactions)

      next_page_path =
        case next_page_params(next_page, epoch_transactions, params) do
          nil ->
            nil

          next_page_params ->
            address_epoch_transaction_path(conn, :index, address_hash, Map.delete(next_page_params, "type"))
        end

      epoch_transactions_json =
        Enum.map(epoch_transactions, fn epoch_transaction ->
          View.render_to_string(
            EpochTransactionView,
            "_election_tile.html",
            epoch_transaction: epoch_transaction
          )
        end)

      json(conn, %{items: epoch_transactions_json, next_page_path: next_page_path})
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp calculate_locked_and_vote_activated_gold(nil) do
    {:ok, zero_wei} = Wei.cast(0)
    {zero_wei, zero_wei}
  end

  defp calculate_locked_and_vote_activated_gold(account_epoch),
    do: {account_epoch.total_locked_gold, Wei.sub(account_epoch.total_locked_gold, account_epoch.nonvoting_locked_gold)}

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      {validator_or_group_sum, voting_sum} = get_sums(address)

      last_account_epoch = CeloAccountEpoch.last_for_address(address_hash)
      {locked_gold, vote_activated_gold} = last_account_epoch |> calculate_locked_and_vote_activated_gold()

      pending_gold = Chain.fetch_sum_available_celo_unlocked_for_address(address_hash)

      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        current_path: Controller.current_full_path(conn),
        exchange_rate: Market.get_exchange_rate("cGLD") || Token.null(),
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        validator_or_group_sum: validator_or_group_sum,
        voting_sum: voting_sum,
        locked_gold: locked_gold,
        vote_activated_gold: vote_activated_gold,
        pending_gold: pending_gold,
        is_proxy: false
      )
    else
      {:restricted_access, _} ->
        not_found(conn)

      :error ->
        not_found(conn)

      {:error, :not_found} ->
        not_found(conn)
    end
  end

  defp get_rewards(address, params) do
    case address.celo_account.account_type do
      "normal" -> CeloElectionRewards.get_paginated_rewards_for_address([address.hash], ["voter"], params)
      type -> CeloElectionRewards.get_paginated_rewards_for_address([address.hash], [type, "voter"], params)
    end
  end

  defp get_sums(address) do
    case address.celo_account.account_type do
      "normal" -> {nil, CeloElectionRewards.get_rewards_sum_for_account(address.hash)}
      type -> CeloElectionRewards.get_rewards_sums_for_account(address.hash, type)
    end
  end
end
