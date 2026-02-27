defmodule BlockScoutWeb.API.V2.ScrollController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain,
    only: [
      next_page_params: 3,
      paging_options: 1,
      split_list_by_page: 1
    ]

  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.Chain.Scroll.Reader

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["scroll"])

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{:bundle => :optional}

  operation :batch,
    summary: "Batch by its number.",
    description: "Retrieves batch info by the given number.",
    parameters: [
      %OpenApiSpex.Parameter{
        name: :number,
        in: :path,
        schema: Schemas.General.IntegerString,
        required: true,
        description: "Batch number in the path."
      }
      | base_params()
    ],
    responses: [
      ok: {"Batch info.", "application/json", Schemas.Scroll.Batch},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/scroll/batches/:number` endpoint.
  """
  @spec batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch(conn, %{number: number}) do
    {number, ""} = Integer.parse(number)

    options =
      [necessity_by_association: @batch_necessity_by_association]
      |> Keyword.merge(@api_true)

    {_, batch} = Reader.batch(number, options)

    if batch == :not_found do
      {:error, :not_found}
    else
      conn
      |> put_status(200)
      |> render(:scroll_batch, %{batch: batch})
    end
  end

  operation :batches,
    summary: "List batches.",
    description: "Retrieves a paginated list of batches.",
    parameters:
      base_params() ++
        define_paging_params([
          "number"
        ]),
    responses: [
      ok:
        {"List of batches.", "application/json",
         paginated_response(
           items: Schemas.Scroll.Batch,
           next_page_params_example: %{
             "number" => 502_655
           },
           title_prefix: "Batches"
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/scroll/batches` endpoint.
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    {batches, next_page} =
      params
      |> paging_options()
      |> Keyword.merge(@api_true)
      |> Reader.batches()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, batches, params)

    conn
    |> put_status(200)
    |> render(:scroll_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  operation :batches_count,
    summary: "Number of batches in the list.",
    description: "Retrieves a size of the batch list.",
    parameters: base_params(),
    responses: [
      ok: {"Number of items in the batch list.", "application/json", %Schema{type: :integer, nullable: false}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/scroll/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:scroll_batches_count, %{count: batch_latest_number() + 1})
  end

  operation :deposits,
    summary: "List deposits.",
    description: "Retrieves a paginated list of deposits.",
    parameters:
      base_params() ++
        define_paging_params([
          "id"
        ]),
    responses: [
      ok:
        {"List of deposits.", "application/json",
         paginated_response(
           items: Schemas.Scroll.Bridge,
           next_page_params_example: %{
             "id" => 986_043
           },
           title_prefix: "Deposits"
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/scroll/deposits` endpoint.
  """
  @spec deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits(conn, params) do
    {deposits, next_page} =
      params
      |> paging_options()
      |> Keyword.merge(@api_true)
      |> Reader.deposits()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, deposits, params)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items, %{
      items: deposits,
      next_page_params: next_page_params,
      type: :deposits
    })
  end

  operation :deposits_count,
    summary: "Number of deposits in the list.",
    description: "Retrieves a size of the deposits list.",
    parameters: base_params(),
    responses: [
      ok: {"Number of items in the deposits list.", "application/json", %Schema{type: :integer, nullable: true}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/scroll/deposits/count` endpoint.
  """
  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    count = Reader.deposits_count(@api_true)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items_count, %{count: count})
  end

  operation :withdrawals,
    summary: "List withdrawals.",
    description: "Retrieves a paginated list of withdrawals.",
    parameters:
      base_params() ++
        define_paging_params([
          "id"
        ]),
    responses: [
      ok:
        {"List of withdrawals.", "application/json",
         paginated_response(
           items: Schemas.Scroll.Bridge,
           next_page_params_example: %{
             "id" => 220_243
           },
           title_prefix: "Withdrawals"
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/scroll/withdrawals` endpoint.
  """
  @spec withdrawals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals(conn, params) do
    {withdrawals, next_page} =
      params
      |> paging_options()
      |> Keyword.merge(@api_true)
      |> Reader.withdrawals()
      |> split_list_by_page()

    next_page_params = next_page_params(next_page, withdrawals, params)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items, %{
      items: withdrawals,
      next_page_params: next_page_params,
      type: :withdrawals
    })
  end

  operation :withdrawals_count,
    summary: "Number of withdrawals in the list.",
    description: "Retrieves a size of the withdrawals list.",
    parameters: base_params(),
    responses: [
      ok: {"Number of items in the withdrawals list.", "application/json", %Schema{type: :integer, nullable: true}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/scroll/withdrawals/count` endpoint.
  """
  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    count = Reader.withdrawals_count(@api_true)

    conn
    |> put_status(200)
    |> render(:scroll_bridge_items_count, %{count: count})
  end

  defp batch_latest_number do
    case Reader.batch(:latest, @api_true) do
      {:ok, batch} -> batch.number
      {:error, :not_found} -> -1
    end
  end
end
