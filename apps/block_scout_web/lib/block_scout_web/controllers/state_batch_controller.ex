defmodule BlockScoutWeb.StateBatchController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain,
    only: [
      fetch_page_number: 1,
      paging_options: 1,
      next_page_params: 3,
      update_page_parameters: 3,
      split_list_by_page: 1
    ]

  alias BlockScoutWeb.{
    AccessHelpers,
    Controller,
    StateBatchView
  }

  alias Explorer.{Chain, Market}
  alias Explorer.Chain.Cache.Transaction, as: TransactionCache
  alias Explorer.ExchangeRates.Token
  alias Phoenix.View

  @necessity_by_association %{
    :block => :optional,
    [created_contract_address: :names] => :optional,
    [from_address: :names] => :optional,
    [to_address: :names] => :optional,
    [to_address: :smart_contract] => :optional,
    :token_transfers => :optional
  }

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  @default_options [
    necessity_by_association: %{
      :block => :required,
      [created_contract_address: :names] => :optional,
      [from_address: :names] => :optional,
      [to_address: :names] => :optional,
      [created_contract_address: :smart_contract] => :optional,
      [from_address: :smart_contract] => :optional,
      [to_address: :smart_contract] => :optional
    }
  ]

  def index(conn, %{"type" => "JSON"} = params) do
    options =
      @default_options
      |> Keyword.merge(paging_options(params))

    full_options =
      options
      |> Keyword.put(
        :paging_options,
        params
        |> fetch_page_number()
        |> update_page_parameters(Chain.default_page_size(), Keyword.get(options, :paging_options))
      )

    %{total_transactions_count: transactions_count, state_batches: state_batches_plus_one} =
      Chain.recent_collated_state_batches_for_rap(full_options)

    {state_batches, next_page} =
      if fetch_page_number(params) == 1 do
        split_list_by_page(state_batches_plus_one)
      else
        {state_batches_plus_one, nil}
      end

    next_page_params =
      if fetch_page_number(params) == 1 do
        page_size = Chain.default_page_size()
        pages_limit = transactions_count |> Kernel./(page_size) |> Float.ceil() |> trunc()
        case next_page_params(next_page, state_batches, params) do
          nil ->
            nil

          next_page_params ->
            next_page_params
            |> Map.delete("type")
            |> Map.delete("items_count")
            |> Map.put("pages_limit", pages_limit)
            |> Map.put("page_size", page_size)
            |> Map.put("page_number", 1)
        end
      else
        Map.delete(params, "type")
      end
    json(
      conn,
      %{
        items:
          Enum.map(state_batches, fn state_batch ->
            View.render_to_string(
              StateBatchView,
              "_tile.html",
              state_batch: state_batch,
              conn: conn
            )
          end),
        next_page_params: next_page_params
      }
    )
  end

  def index(conn, _params) do
    transaction_estimated_count = TransactionCache.estimated_count()

    render(
      conn,
      "index.html",
      current_path: Controller.current_full_path(conn),
      transaction_estimated_count: transaction_estimated_count
    )
  end

  def show(conn, %{"batch_index" => batch_index}) do
    %{state_batch: state_batch} = Chain.state_batch_detail(batch_index);
    render(
          conn,
          "overview.html",
          state_batch: state_batch
        )
  end

end
