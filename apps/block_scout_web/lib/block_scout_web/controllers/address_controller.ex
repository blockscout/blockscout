defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{
    AccessHelpers,
    AddressTransactionController,
    AddressView,
    Controller
  }

  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Wei
  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  def index(conn, %{"type" => "JSON"} = params) do
    addresses =
      params
      |> paging_options()
      |> Chain.list_top_addresses()

    {addresses_page, next_page} = split_list_by_page(addresses)

    next_page_path =
      case next_page_params(next_page, addresses_page, params) do
        nil ->
          nil

        next_page_params ->
          address_path(
            conn,
            :index,
            Map.delete(next_page_params, "type")
          )
      end

    exchange_rate = Market.get_exchange_rate(Explorer.coin()) || Token.null()
    total_supply = Chain.total_supply()

    items_count_str = Map.get(params, "items_count")

    items_count =
      if items_count_str do
        {items_count, _} = Integer.parse(items_count_str)
        items_count
      else
        0
      end

    items =
      addresses_page
      |> Enum.with_index(1)
      |> Enum.map(fn {{address, tx_count}, index} ->
        View.render_to_string(
          AddressView,
          "_tile.html",
          address: address,
          index: items_count + index,
          exchange_rate: exchange_rate,
          total_supply: total_supply,
          tx_count: tx_count
        )
      end)

    json(
      conn,
      %{
        items: items,
        next_page_path: next_page_path
      }
    )
  end

  def index(conn, _params) do
    total_supply = Chain.total_supply()

    render(conn, "index.html",
      current_path: Controller.current_full_path(conn),
      address_count: Chain.address_estimated_count(),
      total_supply: total_supply
    )
  end

  @quai_contexts [
    %{shard: "prime", context: 0, byte: ["00", "09"]},
    %{shard: "cyprus", context: 1, byte: ["0a", "13"]},
    %{shard: "cyprus1", context: 2, byte: ["14", "1d"]},
    %{shard: "cyprus2", context: 2, byte: ["1e", "27"]},
    %{shard: "cyprus3", context: 2, byte: ["28", "31"]},
    %{shard: "paxos", context: 1, byte: ["32", "3b"]},
    %{shard: "paxos1", context: 2, byte: ["3c", "45"]},
    %{shard: "paxos2", context: 2, byte: ["46", "4f"]},
    %{shard: "paxos3", context: 2, byte: ["50", "59"]},
    %{shard: "hydra", context: 1, byte: ["5a", "63"]},
    %{shard: "hydra1", context: 2, byte: ["64", "6d"]},
    %{shard: "hydra2", context: 2, byte: ["6e", "77"]},
    %{shard: "hydra3", context: 2, byte: ["78", "81"]}
  ]

  def get_shard_from_address(address) do
    get_in(
      Enum.at(
        Enum.filter(
          @quai_contexts,
          fn obj ->
            num = address
                  |> String.slice(2, 2)
                  |> String.to_integer(16)
            start = String.to_integer(Enum.at(obj.byte, 0), 16)
            finish = String.to_integer(Enum.at(obj.byte, 1), 16)
            num >= start and num <= finish
          end
        ),
        0
      ),
      [:shard]
    )
  end

  def show(conn, %{"id" => address_hash_string, "type" => "JSON"} = params) do
    AddressTransactionController.index(conn, Map.put(params, "address_id", address_hash_string))
  end

  def show(conn, %{"id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params) do
      shard = get_shard_from_address(address_hash_string)
      if shard != nil and shard != String.downcase(System.get_env("SUBNETWORK")) do
        conn |> redirect(
                  external: "#{conn.scheme}://#{String.replace(conn.host, String.downcase(System.get_env("SUBNETWORK")), shard)}/address/#{address_hash_string}"
                ) |> halt()
      else
        render(
          conn,
          "_show_address_transactions.html",
          address: address,
          coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
          exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
          filter: params["filter"],
          counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
          current_path: Controller.current_full_path(conn),
          tags: get_address_tags(address_hash, current_user(conn))
        )
      end
    else
      :error ->
        unprocessable_entity(conn)

      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        {:ok, address_hash} = Chain.string_to_address_hash(address_hash_string)

        address = %Chain.Address{
          hash: address_hash,
          smart_contract: nil,
          token: nil,
          fetched_coin_balance: %Wei{value: Decimal.new(0)}
        }
        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            render(
              conn,
              "_show_address_transactions.html",
              address: address,
              coin_balance_status: nil,
              exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
              filter: params["filter"],
              counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
              current_path: Controller.current_full_path(conn),
              tags: get_address_tags(address_hash, current_user(conn))
            )

          _ ->
            not_found(conn)
        end
    end
  end

  def address_counters(conn, %{"id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      {validation_count} = Chain.address_counters(address)

      transactions_from_db = address.transactions_count || 0
      token_transfers_from_db = address.token_transfers_count || 0
      address_gas_usage_from_db = address.gas_used || 0

      json(conn, %{
        transaction_count: transactions_from_db,
        token_transfer_count: token_transfers_from_db,
        gas_usage_count: address_gas_usage_from_db,
        validation_count: validation_count
      })
    else
      _ ->
        json(conn, %{
          transaction_count: 0,
          token_transfer_count: 0,
          gas_usage_count: 0,
          validation_count: 0
        })
    end
  end
end
