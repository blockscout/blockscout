defmodule BlockScoutWeb.AddressTransactionController do
  @moduledoc """
    Display all the Transactions that terminate at this Address.
  """

  use BlockScoutWeb, :controller

  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]

  import BlockScoutWeb.Chain, only: [current_filter: 1, paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2]

  alias BlockScoutWeb.{AccessHelper, Controller, TransactionView}
  alias Explorer.{Chain, Market}

  alias Explorer.Chain.CSVExport.{
    AddressInternalTransactionCsvExporter,
    AddressLogCsvExporter,
    AddressTokenTransferCsvExporter,
    AddressTransactionCsvExporter
  }

  alias Explorer.Chain.Wei

  alias Explorer.ExchangeRates.Token
  alias Indexer.Fetcher.CoinBalanceOnDemand
  alias Phoenix.View

  alias Plug.Conn

  @transaction_necessity_by_association [
    necessity_by_association: %{
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      :block => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  def index(conn, %{"address_id" => address_hash_string, "type" => "JSON"} = params) do
    address_options = [necessity_by_association: %{:names => :optional, :smart_contract => :optional}]

    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash, address_options, false),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      options =
        @transaction_necessity_by_association
        |> Keyword.merge(paging_options(params))
        |> Keyword.merge(current_filter(params))

      results_plus_one = Chain.address_to_transactions_with_rewards(address_hash, options)
      {results, next_page} = split_list_by_page(results_plus_one)

      next_page_url =
        case next_page_params(next_page, results, params) do
          nil ->
            nil

          next_page_params ->
            address_transaction_path(
              conn,
              :index,
              address,
              Map.delete(next_page_params, "type")
            )
        end

      items_json =
        Enum.map(results, fn result ->
          case result do
            {%Chain.Block.Reward{} = emission_reward, %Chain.Block.Reward{} = validator_reward} ->
              View.render_to_string(
                TransactionView,
                "_emission_reward_tile.html",
                current_address: address,
                emission_funds: emission_reward,
                validator: validator_reward
              )

            %Chain.Transaction{} = transaction ->
              View.render_to_string(
                TransactionView,
                "_tile.html",
                conn: conn,
                current_address: address,
                transaction: transaction,
                burn_address_hash: @burn_address_hash
              )
          end
        end)

      json(conn, %{items: items_json, next_page_path: next_page_url})
    else
      :error ->
        unprocessable_entity(conn)

      {:restricted_access, _} ->
        not_found(conn)

      {:error, :not_found} ->
        case Chain.Hash.Address.validate(address_hash_string) do
          {:ok, _} ->
            json(conn, %{items: [], next_page_path: ""})

          _ ->
            not_found(conn)
        end
    end
  end

  def index(conn, %{"address_id" => address_hash_string} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params) do
      render(
        conn,
        "index.html",
        address: address,
        coin_balance_status: CoinBalanceOnDemand.trigger_fetch(address),
        exchange_rate: Market.get_exchange_rate(Explorer.coin()) || Token.null(),
        filter: params["filter"],
        counters_path: address_path(conn, :address_counters, %{"id" => address_hash_string}),
        current_path: Controller.current_full_path(conn),
        tags: get_address_tags(address_hash, current_user(conn))
      )
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
              "index.html",
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

  defp captcha_helper do
    :block_scout_web
    |> Application.get_env(:captcha_helper)
  end

  defp put_resp_params(conn) do
    conn
    |> put_resp_content_type("application/csv")
    |> put_resp_header("content-disposition", "attachment;")
    |> put_resp_cookie("csv-downloaded", "true", max_age: 86_400, http_only: false)
    |> send_chunked(200)
  end

  defp items_csv(
         conn,
         %{
           "address_id" => address_hash_string,
           "from_period" => from_period,
           "to_period" => to_period
         },
         csv_export_module
       )
       when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         true <- Application.get_env(:block_scout_web, :recaptcha)[:is_disabled] do
      address
      |> csv_export_module.export(from_period, to_period)
      |> Enum.reduce_while(put_resp_params(conn), fn chunk, conn ->
        case Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            {:halt, conn}
        end
      end)
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)

      false ->
        not_found(conn)
    end
  end

  defp items_csv(
         conn,
         %{
           "address_id" => address_hash_string,
           "from_period" => from_period,
           "to_period" => to_period,
           "recaptcha_response" => recaptcha_response
         },
         csv_export_module
       )
       when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash),
         {:recaptcha, true} <- {:recaptcha, captcha_helper().recaptcha_passed?(recaptcha_response)} do
      address
      |> csv_export_module.export(from_period, to_period)
      |> Enum.reduce_while(put_resp_params(conn), fn chunk, conn ->
        case Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            {:halt, conn}
        end
      end)
    else
      :error ->
        unprocessable_entity(conn)

      {:error, :not_found} ->
        not_found(conn)

      {:recaptcha, false} ->
        not_found(conn)
    end
  end

  defp items_csv(conn, _, _), do: not_found(conn)

  def token_transfers_csv(conn, params) do
    items_csv(
      conn,
      %{
        "address_id" => params["address_id"],
        "from_period" => params["from_period"],
        "to_period" => params["to_period"],
        "recaptcha_response" => params["recaptcha_response"]
      },
      AddressTokenTransferCsvExporter
    )
  end
  
  def transactions_csv(conn, %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period,
        "recaptcha_response" => recaptcha_response
      }) do
    items_csv(
      conn,
      %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period,
        "recaptcha_response" => recaptcha_response
      },
      AddressTransactionCsvExporter
    )
  end

  def internal_transactions_csv(conn, %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period,
        "recaptcha_response" => recaptcha_response
      }) do
    items_csv(
      conn,
      %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period,
        "recaptcha_response" => recaptcha_response
      },
      AddressInternalTransactionCsvExporter
    )
  end

  def logs_csv(conn, %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period,
        "recaptcha_response" => recaptcha_response
      }) do
    items_csv(
      conn,
      %{
        "address_id" => address_hash_string,
        "from_period" => from_period,
        "to_period" => to_period,
        "recaptcha_response" => recaptcha_response
      },
      AddressLogCsvExporter
    )
  end
end
