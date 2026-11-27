# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.OptimismController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  import BlockScoutWeb.Chain,
    only: [
      paginate_list: 3,
      paging_options: 1
    ]

  alias BlockScoutWeb.API.V2.OptimismView
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.{Chain, PagingOptions}
  alias Explorer.Chain.Cache.Counters.Optimism.DepositsCount, as: DepositsCountCache
  alias Explorer.Chain.Transaction

  alias Explorer.Chain.Optimism.{
    Deposit,
    DisputeGame,
    FrameSequence,
    FrameSequenceBlob,
    OutputRoot,
    TransactionBatch,
    Withdrawal
  }

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  tags(["optimism"])

  @api_true [api?: true]

  operation :batches,
    summary: "List batches.",
    description: "Retrieves a paginated list of batches.",
    parameters:
      base_params() ++
        define_paging_params(["id"]),
    responses: [
      ok:
        {"List of batches.", "application/json",
         paginated_response(
           items: Schemas.Optimism.Batch,
           next_page_params_example: %{
             "id" => 394_591
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/batches` endpoint.
  """
  @spec batches(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches(conn, params) do
    options =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)
      |> Keyword.put(:only_view_ready?, true)

    {batches, next_page_params} =
      options
      |> FrameSequence.list()
      |> paginate_list(params, options[:paging_options])

    items =
      batches
      |> Enum.map(fn fs ->
        Task.async(fn ->
          l2_block_number_from = TransactionBatch.edge_l2_block_number(fs.id, :min, @api_true)
          l2_block_number_to = TransactionBatch.edge_l2_block_number(fs.id, :max, @api_true)

          l2_block_range =
            if not is_nil(l2_block_number_from) and not is_nil(l2_block_number_to) do
              l2_block_number_from..l2_block_number_to
            end

          # credo:disable-for-lines:2 Credo.Check.Refactor.Nesting
          transactions_count =
            case l2_block_range do
              nil -> 0
              range -> Transaction.transaction_count_for_block_range(range)
            end

          {batch_data_container, _} = FrameSequenceBlob.list(fs.id, api?: true)

          fs
          |> Map.put(:l2_block_range, l2_block_range)
          |> Map.put(:transactions_count, transactions_count)
          |> Map.put(:batch_data_container, batch_data_container)
        end)
      end)
      |> Task.yield_many(:infinity)
      |> Enum.map(fn {_task, {:ok, item}} -> item end)
      |> Enum.reject(&is_nil(&1.l2_block_range))

    conn
    |> put_status(200)
    |> render(:optimism_batches, %{
      batches: items,
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
  Function to handle GET requests to `/api/v2/optimism/batches/count` endpoint.
  """
  @spec batches_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batches_count(conn, _params) do
    items_count(conn, FrameSequence)
  end

  operation :batch_by_celestia_blob,
    summary: "Batch by celestia blob.",
    description: "Retrieves batch detailed info by the given celestia blob metadata (height and commitment).",
    parameters:
      base_params() ++
        [
          %OpenApiSpex.Parameter{
            name: :height,
            in: :path,
            schema: Schemas.General.IntegerString,
            required: true,
            description: "Celestia blob height in the path."
          },
          %OpenApiSpex.Parameter{
            name: :commitment,
            in: :path,
            schema: Schemas.General.HexData,
            required: true,
            description: "Celestia blob commitment in the path."
          }
        ],
    responses: [
      ok: {"Batch detailed info.", "application/json", Schemas.Optimism.Batch.Detailed},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/batches/da/celestia/:height/:commitment` endpoint.
  """
  @spec batch_by_celestia_blob(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_by_celestia_blob(conn, %{height: height, commitment: commitment}) do
    {height, ""} = Integer.parse(height)

    commitment =
      if String.starts_with?(String.downcase(commitment), "0x") do
        commitment
      else
        "0x" <> commitment
      end

    batch = FrameSequence.batch_by_celestia_blob(commitment, height, api?: true)

    if is_nil(batch) do
      {:error, :not_found}
    else
      conn
      |> put_status(200)
      |> render(:optimism_batch, %{batch: batch})
    end
  end

  operation :batch_by_number,
    summary: "Batch by its number.",
    description: "Retrieves batch detailed info by the given number.",
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
      ok: {"Batch detailed info.", "application/json", Schemas.Optimism.Batch.Detailed},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/batches/:number` endpoint.
  """
  @spec batch_by_number(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def batch_by_number(conn, %{number: number}) do
    {number, ""} = Integer.parse(number)

    batch = FrameSequence.batch_by_number(number, api?: true)

    if is_nil(batch) do
      {:error, :not_found}
    else
      conn
      |> put_status(200)
      |> render(:optimism_batch, %{batch: batch})
    end
  end

  operation :output_roots,
    summary: "List output roots.",
    description: "Retrieves a paginated list of output roots.",
    parameters:
      base_params() ++
        define_paging_params(["index"]),
    responses: [
      ok:
        {"List of output roots.", "application/json",
         paginated_response(
           items: Schemas.Optimism.OutputRoot,
           next_page_params_example: %{
             "index" => 8829
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/output-roots` endpoint.
  """
  @spec output_roots(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def output_roots(conn, params) do
    roots_options =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)

    {roots, next_page_params} =
      roots_options
      |> OutputRoot.list()
      |> paginate_list(params, roots_options[:paging_options])

    conn
    |> put_status(200)
    |> render(:optimism_output_roots, %{
      roots: roots,
      next_page_params: next_page_params
    })
  end

  operation :output_roots_count,
    summary: "Number of output roots in the list.",
    description: "Retrieves a size of the output roots list.",
    parameters: base_params(),
    responses: [
      ok: {"Number of items in the output roots list.", "application/json", %Schema{type: :integer, nullable: false}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/output-roots/count` endpoint.
  """
  @spec output_roots_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def output_roots_count(conn, _params) do
    items_count(conn, OutputRoot)
  end

  operation :games,
    summary: "List games.",
    description: "Retrieves a paginated list of games.",
    parameters:
      base_params() ++
        define_paging_params(["index"]),
    responses: [
      ok:
        {"List of games.", "application/json",
         paginated_response(
           items: Schemas.Optimism.Game,
           next_page_params_example: %{
             "index" => 12967
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/games` endpoint.
  """
  @spec games(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def games(conn, params) do
    games_options =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)

    {games, next_page_params} =
      games_options
      |> DisputeGame.list()
      |> paginate_list(params, games_options[:paging_options])

    conn
    |> put_status(200)
    |> render(:optimism_games, %{
      games: games,
      next_page_params: next_page_params
    })
  end

  operation :games_count,
    summary: "Number of games in the list.",
    description: "Retrieves a size of the games list.",
    parameters: base_params(),
    responses: [
      ok: {"Number of items in the games list.", "application/json", %Schema{type: :integer, nullable: false}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/games/count` endpoint.
  """
  @spec games_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def games_count(conn, _params) do
    count = DisputeGame.get_last_known_index() + 1

    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: count})
  end

  operation :deposits,
    summary: "List deposits.",
    description: "Retrieves a paginated list of deposits.",
    parameters:
      base_params() ++
        define_paging_params(["l1_block_number", "transaction_hash"]),
    responses: [
      ok:
        {"List of deposits.", "application/json",
         paginated_response(
           items: Schemas.Optimism.Deposit,
           next_page_params_example: %{
             "l1_block_number" => 23_937_283,
             "transaction_hash" => "0x5dc155c382d95353c5876e735d675d284e3b29b1379e5859dc35cfd4a1dd5188"
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/deposits` endpoint.
  """
  @spec deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits(conn, params) do
    deposits_options =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)

    {deposits, next_page_params} =
      deposits_options
      |> Deposit.list()
      |> paginate_list(params, deposits_options[:paging_options])

    conn
    |> put_status(200)
    |> render(:optimism_deposits, %{
      deposits: deposits,
      next_page_params: next_page_params
    })
  end

  operation :main_page_deposits,
    summary: "List deposits on the main page.",
    description: "Retrieves a list of deposits for the main page.",
    parameters: base_params(),
    responses: [
      ok:
        {"List of deposits on the main page.", "application/json",
         %Schema{type: :array, items: Schemas.Optimism.Deposit.MainPage, nullable: false}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/main-page/optimism-deposits` endpoint.
  """
  @spec main_page_deposits(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def main_page_deposits(conn, _params) do
    recent_deposits =
      Deposit.list(
        paging_options: %PagingOptions{page_size: 6},
        api?: true
      )

    conn
    |> put_status(200)
    |> put_view(OptimismView)
    |> render(:optimism_deposits, %{deposits: recent_deposits})
  end

  operation :deposits_count,
    summary: "Number of deposits in the list.",
    description: "Retrieves a size of the deposits list.",
    parameters: base_params(),
    responses: [
      ok: {"Number of items in the deposits list.", "application/json", %Schema{type: :integer, nullable: false}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/deposits/count` endpoint.
  """
  @spec deposits_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def deposits_count(conn, _params) do
    count =
      case DepositsCountCache.fetch(@api_true) do
        nil -> Chain.get_table_rows_total_count(Deposit, @api_true)
        cached_count -> Decimal.to_integer(cached_count)
      end

    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: count})
  end

  operation :withdrawals,
    summary: "List withdrawals.",
    description: "Retrieves a paginated list of withdrawals.",
    parameters:
      base_params() ++
        define_paging_params(["nonce"]),
    responses: [
      ok:
        {"List of withdrawals.", "application/json",
         paginated_response(
           items: Schemas.Optimism.Withdrawal,
           next_page_params_example: %{
             "nonce" => "1766847064778384329583297500742918515827483896875618958121606201292650102"
           }
         )},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/withdrawals` endpoint.
  """
  @spec withdrawals(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals(conn, params) do
    withdrawals_options =
      params
      |> paging_options()
      |> Keyword.put(:api?, true)

    {withdrawals, next_page_params} =
      withdrawals_options
      |> Withdrawal.list()
      |> paginate_list(params, withdrawals_options[:paging_options])

    conn
    |> put_status(200)
    |> render(:optimism_withdrawals, %{
      withdrawals: withdrawals,
      next_page_params: next_page_params
    })
  end

  operation :withdrawals_count,
    summary: "Number of withdrawals in the list.",
    description: "Retrieves a size of the withdrawals list.",
    parameters: base_params(),
    responses: [
      ok: {"Number of items in the withdrawals list.", "application/json", %Schema{type: :integer, nullable: false}},
      unprocessable_entity: JsonErrorResponse.response()
    ]

  @doc """
  Function to handle GET requests to `/api/v2/optimism/withdrawals/count` endpoint.
  """
  @spec withdrawals_count(Plug.Conn.t(), map()) :: Plug.Conn.t()
  def withdrawals_count(conn, _params) do
    items_count(conn, Withdrawal)
  end

  defp items_count(conn, module) do
    count = Chain.get_table_rows_total_count(module, api?: true)

    conn
    |> put_status(200)
    |> render(:optimism_items_count, %{count: count})
  end
end
