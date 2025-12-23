defmodule BlockScoutWeb.API.V2.WithdrawalController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, next_page_params: 3, split_list_by_page: 1]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias Explorer.Chain

  tags(["withdrawals"])

  operation :withdrawals_list,
    summary: "List validator withdrawal details on proof-of-stake networks",
    description:
      "Retrieves a paginated list of withdrawals, typically for proof-of-stake networks supporting validator withdrawals.",
    parameters:
      base_params() ++
        define_paging_params(["index", "items_count"]),
    responses: [
      ok:
        {"List of withdrawals with pagination.", "application/json",
         paginated_response(
           items: Schemas.Withdrawal,
           next_page_params_example: %{
             "index" => 50,
             "items_count" => 50
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  def withdrawals_list(conn, params) do
    full_options =
      [
        necessity_by_association: %{
          [address: [:names, :smart_contract, proxy_implementations_association()]] => :optional,
          block: :optional
        },
        api?: true
      ]
      |> Keyword.merge(paging_options(params))

    withdrawals_plus_one = Chain.list_withdrawals(full_options)
    {withdrawals, next_page} = split_list_by_page(withdrawals_plus_one)

    next_page_params = next_page |> next_page_params(withdrawals, params)

    conn
    |> put_status(200)
    |> render(:withdrawals, %{
      withdrawals: withdrawals |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  operation :withdrawals_counters,
    summary: "Withdrawals counters",
    description: "Returns total withdrawals count and sum from cache.",
    parameters: base_params(),
    responses: [
      ok: {"Withdrawals counters.", "application/json", Schemas.Withdrawal.Counter},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  def withdrawals_counters(conn, _params) do
    conn
    |> json(%{
      withdrawals_count: Chain.count_withdrawals_from_cache(api?: true),
      withdrawals_sum: Chain.sum_withdrawals_from_cache(api?: true)
    })
  end
end
