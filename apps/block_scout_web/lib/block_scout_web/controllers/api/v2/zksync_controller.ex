# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.ZkSyncController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain,
    only: [
      paginate_list: 4,
      paging_options: 1
    ]

  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.Chain.ZkSync.{Reader, TransactionBatch}

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["zksync"])

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  @batch_necessity_by_association %{
    :commit_transaction => :optional,
    :prove_transaction => :optional,
    :execute_transaction => :optional
  }

  operation :batch,
    summary: "Get batch by number.",
    description: "Retrieves detailed information about a ZkSync batch by its number.",
    parameters: [batch_number_param() | base_params()],
    responses: [
      ok: {"Batch info.", "application/json", Schemas.ZkSync.Batch},
      not_found: NotFoundResponse.response(),
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/zksync/batches/:batch_number_param` endpoint.
  """
  @spec batch(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch(conn, %{batch_number_param: batch_number} = _params) do
    case Reader.batch(
           batch_number,
           necessity_by_association: @batch_necessity_by_association,
           api?: true
         ) do
      {:ok, batch} ->
        conn
        |> put_status(200)
        |> render(:zksync_batch, %{batch: batch})

      {:error, :not_found} = res ->
        res
    end
  end

  operation :batches,
    summary: "List batches.",
    description: "Retrieves a paginated list of ZkSync rollup batches, newest first.",
    parameters:
      base_params() ++
        define_paging_params(["number"]),
    responses: [
      ok:
        {"List of batches.", "application/json",
         paginated_response(
           items: Schemas.ZkSync.BatchListItem,
           next_page_params_example: %{"number" => 502_655}
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/zksync/batches` endpoint.
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    zksync_options =
      params
      |> paging_options()
      |> Keyword.put(:necessity_by_association, @batch_necessity_by_association)
      |> Keyword.put(:api?, true)

    {batches, next_page_params} =
      zksync_options
      |> Reader.batches()
      |> paginate_list(params, zksync_options[:paging_options],
        paging_function: fn %TransactionBatch{number: number} -> %{number: number} end
      )

    conn
    |> put_status(200)
    |> render(:zksync_batches, %{
      batches: batches,
      next_page_params: next_page_params
    })
  end

  operation :batches_count,
    summary: "Get batches count.",
    description: "Retrieves the total count of ZkSync rollup batches.",
    parameters: base_params(),
    responses: [
      ok: {"Total count of batches.", "application/json", %Schema{type: :integer, minimum: 0}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
    Function to handle GET requests to `/api/v2/zksync/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    conn
    |> put_status(200)
    |> render(:zksync_batches_count, %{count: Reader.batches_count(api?: true)})
  end

  operation :batches_confirmed,
    summary: "List confirmed batches on the main page.",
    description: "Retrieves up to ten most-recently-committed ZkSync rollup batches, displayed on the main page.",
    parameters: base_params(),
    responses: [
      ok:
        {"List of confirmed ZkSync batches.", "application/json",
         %Schema{
           type: :object,
           properties: %{
             items: %Schema{
               type: :array,
               items: Schemas.ZkSync.ConfirmedBatchListItem,
               nullable: false
             }
           },
           required: [:items],
           additionalProperties: false
         }},
      unprocessable_entity: JsonErrorResponse.response()
    ],
    tags: ["main-page"]

  @doc """
    Function to handle GET requests to `/api/v2/main-page/zksync/batches/confirmed` endpoint.
  """
  @spec batches_confirmed(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_confirmed(conn, _params) do
    batches =
      []
      |> Keyword.put(:necessity_by_association, @batch_necessity_by_association)
      |> Keyword.put(:api?, true)
      |> Keyword.put(:confirmed?, true)
      |> Reader.batches()

    conn
    |> put_status(200)
    |> render(:zksync_batches, %{batches: batches})
  end

  operation :batch_latest_number,
    summary: "Get the latest batch number.",
    description: "Retrieves the number of the most recent ZkSync rollup batch. Returns 0 if no batches exist.",
    parameters: base_params(),
    responses: [
      ok: {"Latest ZkSync batch number.", "application/json", %Schema{type: :integer, minimum: 0}},
      unprocessable_entity: JsonErrorResponse.response()
    ],
    tags: ["main-page"]

  @doc """
    Function to handle GET requests to `/api/v2/main-page/zksync/batches/latest-number` endpoint.
  """
  @spec batch_latest_number(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_latest_number(conn, _params) do
    conn
    |> put_status(200)
    |> render(:zksync_batch_latest_number, %{number: batch_latest_number()})
  end

  defp batch_latest_number do
    case Reader.batch(:latest, api?: true) do
      {:ok, batch} -> batch.number
      {:error, :not_found} -> 0
    end
  end
end
