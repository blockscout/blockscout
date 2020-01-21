defmodule BlockScoutWeb.AddressController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  alias BlockScoutWeb.AddressView
  alias Explorer.{Chain, Market}
  alias Explorer.ExchangeRates.Token
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

    items =
      addresses_page
      |> Enum.with_index(1)
      |> Enum.map(fn {{address, tx_count}, index} ->
        View.render_to_string(
          AddressView,
          "_tile.html",
          address: address,
          index: index,
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
    render(conn, "index.html",
      current_path: current_path(conn),
      address_count: Chain.address_estimated_count()
    )
  end

  def show(conn, %{"id" => id}) do
    redirect(conn, to: address_transaction_path(conn, :index, id))
  end

  def address_counters(conn, %{"id" => address_hash_string}) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:ok, address} <- Chain.hash_to_address(address_hash) do
      {transaction_count, validation_count} = transaction_and_validation_count(address)

      json(conn, %{transaction_count: transaction_count, validation_count: validation_count})
    else
      _ -> not_found(conn)
    end
  end

  def transaction_and_validation_count(address) do
    transaction_count_task =
      Task.async(fn ->
        transaction_count(address)
      end)

    validation_count_task =
      Task.async(fn ->
        validation_count(address)
      end)

    [transaction_count_task, validation_count_task]
    |> Task.yield_many(:timer.seconds(60))
    |> Enum.map(fn {_task, res} ->
      case res do
        {:ok, result} ->
          result

        {:exit, reason} ->
          raise "Query fetching address counters terminated: #{inspect(reason)}"

        nil ->
          raise "Query fetching address counters timed out."
      end
    end)
    |> List.to_tuple()
  end

  defp transaction_count(address) do
    address_hash_string = to_string(address)
    # if contract?(address) do
    case Chain.Hash.Address.validate(address_hash_string) do
      {:ok, _} ->
        incoming_transaction_count = Chain.address_to_incoming_transaction_count(address)

        if incoming_transaction_count == 0 do
          Chain.total_transactions_sent_by_address(address)
        else
          incoming_transaction_count
        end

      _ ->
        Chain.total_transactions_sent_by_address(address)
    end
  end

  defp validation_count(address) do
    Chain.address_to_validation_count(address)
  end

  #  @spec contract?(Hash.Address.t()) :: boolean()
  #  defp contract?(_), do: true
  #
  #  defp contract?(%{x: nil}), do: false
  #
  #  defp contract?(%{contract_code: _}), do: false
end
