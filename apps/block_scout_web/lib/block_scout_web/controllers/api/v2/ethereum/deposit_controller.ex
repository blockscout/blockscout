defmodule BlockScoutWeb.API.V2.Ethereum.DepositController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain, only: [next_page_params: 5, split_list_by_page: 1]
  import Explorer.MicroserviceInterfaces.BENS, only: [maybe_preload_ens: 1]
  import Explorer.MicroserviceInterfaces.Metadata, only: [maybe_preload_metadata: 1]

  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Beacon.Deposit

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags ["beacon_deposits"]

  operation :list,
    summary: "Lists all beacon deposits",
    description: "Retrieves a paginated list of all beacon deposits.",
    parameters: base_params() ++ define_paging_params(["deposit_index", "items_count"]),
    responses: [
      ok:
        {"List of Beacon Deposits, with pagination.", "application/json",
         paginated_response(
           items: Schemas.Beacon.Deposit,
           next_page_params_example: %{
             "index" => 123,
             "items_count" => 50
           }
         )},
      forbidden: ForbiddenResponse.response()
    ]

  @doc """
  Handles `api/v2/beacon/deposits` endpoint.
  Lists all beacon deposits with pagination support.

  This endpoint retrieves all beacon deposits from the blockchain in a
  paginated format. The results include preloaded associations for both the
  from_address and withdrawal_address, including scam badges, names, smart
  contracts, and proxy implementations. The response may include ENS and
  metadata enrichment if those services are enabled.

  ## Parameters
  - `conn`: The Plug connection.
  - `params`: A map containing optional pagination parameters:
    - `"index"`: non-negative integer, the starting index for pagination.

  ## Returns
  - `Plug.Conn.t()` - A 200 response with rendered deposits and pagination
    information.
  """
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
      |> next_page_params(deposits, params, false, paging_function())

    conn
    |> put_status(200)
    |> render(:deposits, %{
      deposits: deposits |> maybe_preload_ens() |> maybe_preload_metadata(),
      next_page_params: next_page_params
    })
  end

  operation :count,
    summary: "Gets total count of beacon deposits",
    description: "Retrieves the total count of beacon deposits.",
    responses: [
      ok:
        {"Total count of beacon deposits.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             deposits_count: %Schema{type: :integer, nullable: false}
           },
           required: [:deposits_count],
           additionalProperties: false
         }},
      forbidden: ForbiddenResponse.response()
    ]

  @doc """
  Handles `api/v2/beacon/deposits/count` endpoint.
  Returns the total count of beacon deposits.

  This endpoint calculates the total number of beacon deposits by retrieving
  the latest deposit's index. Since deposit indices are 0-based and sequential,
  the total count equals the highest index plus one. If no deposits exist, the
  count is 0.

  ## Parameters
  - `conn`: The Plug connection.

  ## Returns
  - `Plug.Conn.t()` - A JSON response containing:
    - `deposits_count`: The total number of beacon deposits (integer).
  """
  @spec count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def count(conn, _params) do
    last_deposit = Deposit.get_latest_deposit(api?: true) || %{index: -1}

    conn |> json(%{deposits_count: last_deposit.index + 1})
  end

  @spec paging_options(map()) :: [Chain.paging_options()]
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

  @spec paging_function() :: (Deposit.t() -> %{index: non_neg_integer()})
  def paging_function,
    do: fn deposit ->
      %{index: deposit.index}
    end
end
