defmodule BlockScoutWeb.API.V2.WithdrawalController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain,
    only: [paging_options: 1, paginate_list: 3]

  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias Explorer.Chain
  alias Explorer.Chain.Withdrawal

  tags(["withdrawals"])

  operation :withdrawals_list,
    summary: "List validator withdrawal details on proof-of-stake networks",
    description:
      "Retrieves a paginated list of withdrawals, typically for proof-of-stake networks supporting validator withdrawals.",
    parameters:
      base_params() ++
        define_paging_params(["index"]),
    responses: [
      ok:
        {"List of withdrawals with pagination.", "application/json",
         paginated_response(
           items: Schemas.Withdrawal,
           next_page_params_example: %{
             "index" => 50
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

    {withdrawals, next_page_params} = paginate_list(withdrawals_plus_one, params, full_options[:paging_options])

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
      withdrawals_count: Withdrawal.count_withdrawals_from_cache(api?: true),
      withdrawals_sum: Withdrawal.sum_withdrawals_from_cache(api?: true)
    })
  end
end
