defmodule BlockScoutWeb.API.V2.DepositController do
  use BlockScoutWeb, :controller

  import BlockScoutWeb.Chain, only: [next_page_params: 4, split_list_by_page: 1]
  import BlockScoutWeb.PagingHelper, only: [delete_parameters_from_next_page_params: 1]
  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias Explorer.Chain.Beacon.Deposit
  alias Explorer.PagingOptions

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @spec list(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def list(conn, params) do
    full_options =
      [
        necessity_by_association: %{
          [from_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional,
          [withdrawal_address: [:scam_badge, :names, :smart_contract, proxy_implementations_association()]] => :optional
        },
        api?: true
      ]
      |> Keyword.merge(paging_options(params))

    deposit_plus_one = Deposit.all(full_options)
    {deposits, next_page} = split_list_by_page(deposit_plus_one)

    next_page_params =
      next_page
      |> next_page_params(deposits, delete_parameters_from_next_page_params(params), paging_function())

    conn
    |> put_status(200)
    |> render(:deposits, %{
      deposits: deposits |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  def count(conn, _params) do
    last_deposit = Deposit.get_latest_deposit(api?: true) || %{index: -1}

    conn |> json(%{deposits_count: last_deposit.index + 1})
  end

  def paging_options(%{"index" => index}) do
    case Integer.parse(index) do
      {index, ""} -> [paging_options: %{PagingOptions.default_paging_options() | key: %{index: index}}]
      _ -> [paging_options: PagingOptions.default_paging_options()]
    end
  end

  def paging_options(%{index: index}) do
    [paging_options: %{PagingOptions.default_paging_options() | key: %{index: index}}]
  end

  def paging_options(_), do: [paging_options: PagingOptions.default_paging_options()]

  def paging_function,
    do: fn deposit ->
      %{index: deposit.index}
    end
end
