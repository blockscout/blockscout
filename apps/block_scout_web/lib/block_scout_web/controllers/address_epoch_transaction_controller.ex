defmodule BlockScoutWeb.AddressEpochTransactionController do
  @moduledoc """
    Manages the displaying of information about epoch transactions as they relate to addresses
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]
  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelpers, Controller, EpochTransactionView}
  alias Explorer.Celo.EpochUtil
  alias Explorer.{Chain, Market}
  alias Explorer.Chain.CeloElectionRewards
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

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        current_path: Controller.current_full_path(conn),
        exchange_rate: Market.get_exchange_rate("cGLD") || Token.null(),
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        is_proxy: false,
        tags: get_address_tags(address_hash, current_user(conn)),
        celo_epoch: EpochUtil.get_address_summary(address)
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

  defp get_rewards(%Chain.Address{celo_account: nil, hash: address_hash}, params) do
    CeloElectionRewards.get_paginated_rewards_for_address([address_hash], ["delegated_payment"], params)
  end

  defp get_rewards(address, params) do
    case address.celo_account.account_type do
      "normal" ->
        CeloElectionRewards.get_paginated_rewards_for_address([address.hash], ["voter", "delegated_payment"], params)

      type ->
        CeloElectionRewards.get_paginated_rewards_for_address(
          [address.hash],
          [type, "voter", "delegated_payment"],
          params
        )
    end
  end
end
