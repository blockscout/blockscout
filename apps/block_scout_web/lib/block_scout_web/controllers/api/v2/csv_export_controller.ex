defmodule BlockScoutWeb.API.V2.CsvExportController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.CsvExport.Address.InternalTransactions, as: AddressInternalTransactionsCsvExporter
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.CsvExport.Address.Logs, as: AddressLogsCsvExporter
  alias Explorer.Chain.CsvExport.Address.TokenTransfers, as: AddressTokenTransfersCsvExporter
  alias Explorer.Chain.CsvExport.Address.Transactions, as: AddressTransactionsCsvExporter

  alias Explorer.Chain.CsvExport.Address.Celo.ElectionRewards,
    as: AddressCeloElectionRewardsCsvExporter

  alias Explorer.Chain.CsvExport.AsyncHelper, as: AsyncCsvHelper
  alias Explorer.Chain.CsvExport.Helper, as: CsvHelper
  alias Explorer.Chain.CsvExport.Request, as: AsyncCsvExportRequest
  alias Plug.Conn

  import BlockScoutWeb.Chain, only: [fetch_scam_token_toggle: 2]

  require Logger

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  @api_true [api?: true]

  # todo: wrap it into csv_export_module format
  operation :export_token_holders,
    summary: "Export token holders as CSV",
    description: "Exports the holders of a specific token as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param()
        ],
    responses: [
      ok: {"CSV file of token holders.", "application/csv", nil},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ],
    tags: ["tokens"]

  @doc """
  Performs CSV export of token holders for a given address
  Endpoint: `/api/v2/tokens/:address_hash_param/holders/csv`
  """
  @spec export_token_holders(Conn.t(), map()) :: Conn.t()
  def export_token_holders(conn, %{address_hash_param: address_hash_string} = params) do
    with {:format, {:ok, address_hash}} <- {:format, Chain.string_to_address_hash(address_hash_string)},
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         {:not_found, {:ok, token}} <- {:not_found, Chain.token_from_address_hash(address_hash, @api_true)} do
      token_holders = Chain.fetch_token_holders_from_token_hash_for_csv(address_hash, options())

      token_holders
      |> CurrentTokenBalance.to_csv_format(token)
      |> CsvHelper.dump_to_stream()
      |> Enum.reduce_while(put_resp_params(conn), fn chunk, conn ->
        case Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            {:halt, conn}
        end
      end)
    end
  end

  @spec put_resp_params(Conn.t()) :: Conn.t()
  def put_resp_params(conn) do
    conn
    |> put_resp_content_type("application/csv")
    |> put_resp_header("content-disposition", "attachment;")
    |> put_resp_cookie("csv-downloaded", "true", max_age: 86_400, http_only: false)
    |> send_chunked(200)
  end

  defp options, do: [paging_options: CsvHelper.paging_options(), api?: true]

  defp items_csv(
         conn,
         %{
           address_hash_param: address_hash_string,
           from_period: _from_period,
           to_period: _to_period
         } = params,
         csv_export_module
       )
       when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:address_exists, true} <- {:address_exists, Address.address_exists?(address_hash)} do
      do_async_csv?(
        CsvHelper.async_enabled?(),
        conn,
        Map.merge(params, %{
          address_hash: address_hash,
          show_scam_tokens?: fetch_scam_token_toggle([], conn)[:show_scam_tokens?]
        }),
        csv_export_module
      )
    else
      :error ->
        unprocessable_entity(conn)

      {:address_exists, false} ->
        not_found(conn)
    end
  end

  defp items_csv(conn, _, _), do: not_found(conn)

  defp do_async_csv?(true, conn, params, csv_export_module) do
    params =
      params
      |> Map.take([:address_hash, :from_period, :to_period, :filter_type, :filter_value, :show_scam_tokens?])
      |> Map.put(:module, to_string(csv_export_module))

    case AsyncCsvExportRequest.create(AccessHelper.conn_to_ip_string(conn), params) do
      {:ok, %{request: request}} ->
        conn |> put_status(:accepted) |> json(%{request_id: request.id})

      {:error, :too_many_pending_requests} ->
        conn
        |> put_status(:too_many_requests)
        |> json(%{error: "You can only have #{AsyncCsvHelper.max_pending_tasks_per_ip()} pending requests at a time"})

      {:error, error} ->
        Logger.error("Failed to create CSV export request: #{inspect(error)}")
        conn |> put_status(:internal_server_error) |> json(%{error: "Failed to create CSV export request"})
    end
  end

  defp do_async_csv?(false, conn, params, csv_export_module) do
    params[:address_hash]
    |> csv_export_module.export(
      params[:from_period],
      params[:to_period],
      [show_scam_tokens?: params[:show_scam_tokens?]],
      params[:filter_type],
      params[:filter_value]
    )
    |> Enum.reduce_while(put_resp_params(conn), fn chunk, conn ->
      case Conn.chunk(conn, chunk) do
        {:ok, conn} ->
          {:cont, conn}

        {:error, :closed} ->
          {:halt, conn}
      end
    end)
  end

  operation :token_transfers_csv,
    summary: "Export token transfers as CSV",
    description: "Exports token transfers for a specific address as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param()
        ],
    responses: [
      ok: {"CSV file of token transfers.", "application/csv", nil},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ],
    tags: ["addresses"]

  @doc """
  Handles CSV export of token transfers for a given address.

  ## Parameters

    - `conn`: The Plug connection.
    - `params`: A map of request parameters.

  ## Returns

    - The updated Plug connection with the CSV response.

  Delegates the CSV generation to `AddressTokenTransfersCsvExporter`.
  """
  @spec token_transfers_csv(Conn.t(), map()) :: Conn.t()
  def token_transfers_csv(conn, params) do
    items_csv(conn, params, AddressTokenTransfersCsvExporter)
  end

  operation :transactions_csv,
    summary: "Export transactions as CSV",
    description: "Exports transactions for a specific address as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param(),
          recaptcha_response_param()
        ],
    responses: [
      ok: {"CSV file of transactions.", "application/csv", nil},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ],
    tags: ["addresses"]

  @doc """
  Exports transactions related to a specific address in CSV format.

  ## Parameters

    - `conn`: The Plug connection.
    - `params`: A map containing request parameters.

  ## Returns

    - The updated Plug connection with the CSV response.

  This endpoint delegates CSV generation to `AddressTransactionsCsvExporter`.
  """
  @spec transactions_csv(Conn.t(), map()) :: Conn.t()
  def transactions_csv(conn, params) do
    items_csv(conn, params, AddressTransactionsCsvExporter)
  end

  operation :internal_transactions_csv,
    summary: "Export internal transactions as CSV",
    description: "Exports internal transactions for a specific address as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param(),
          recaptcha_response_param()
        ],
    responses: [
      ok: {"CSV file of internal transactions.", "application/csv", nil},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ],
    tags: ["addresses"]

  @doc """
  Exports internal transactions as a CSV file.

  ## Parameters

    - `conn`: The Plug connection.
    - `params`: A map of request parameters.

  ## Returns

    - The updated Plug connection with the CSV response.

  This function delegates the CSV export logic to `AddressInternalTransactionsCsvExporter`.
  """
  @spec internal_transactions_csv(Conn.t(), map()) :: Conn.t()
  def internal_transactions_csv(conn, params) do
    items_csv(conn, params, AddressInternalTransactionsCsvExporter)
  end

  operation :logs_csv,
    summary: "Export logs as CSV",
    description: "Exports logs for a specific address as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param()
        ],
    responses: [
      ok: {"CSV file of logs.", "application/csv", nil},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ],
    tags: ["addresses"]

  @doc """
  Exports logs as a CSV file.

  This controller action receives a connection and parameters, then delegates
  the CSV export functionality to the `AddressLogsCsvExporter` module.

  ## Parameters

    - `conn`: The Plug connection.
    - `params`: A map of request parameters.

  ## Returns

    - The updated Plug connection with the CSV response.
  """
  @spec logs_csv(Conn.t(), map()) :: Conn.t()
  def logs_csv(conn, params) do
    items_csv(conn, params, AddressLogsCsvExporter)
  end

  operation :celo_election_rewards_csv,
    summary: "Export Celo election rewards as CSV",
    description: "Exports Celo election rewards for a specific address as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param()
        ],
    responses: [
      ok: {"CSV file of Celo election rewards.", "application/csv", nil},
      unprocessable_entity: JsonErrorResponse.response(),
      not_found: NotFoundResponse.response()
    ],
    tags: ["addresses"]

  @doc """
  Handles the CSV export of Celo election rewards.

  Receives a connection and parameters, and delegates the CSV generation
  to the `AddressCeloElectionRewardsCsvExporter` module.

  ## Parameters

    - `conn`: The Plug connection.
    - `params`: A map of request parameters.

  ## Returns

    - The updated Plug connection with the CSV response.
  """
  @spec celo_election_rewards_csv(Conn.t(), map()) :: Conn.t()
  def celo_election_rewards_csv(conn, params) do
    items_csv(conn, params, AddressCeloElectionRewardsCsvExporter)
  end

  operation :get_csv_export,
    summary: "Get CSV export",
    description: "Gets a CSV export by UUID",
    parameters: [uuid_param() | base_params()],
    responses: [
      ok: {"Status of CSV export.", "application/json", Schemas.CSVExport.Response},
      not_found: NotFoundResponse.response()
    ],
    tags: ["csv-export"]

  @doc """
  Gets a CSV export by UUID.
  """
  @spec get_csv_export(Conn.t(), map()) :: Conn.t()
  def get_csv_export(conn, %{uuid: uuid}) do
    with {:not_found, request} when not is_nil(request) <-
           {:not_found,
            uuid |> AsyncCsvExportRequest.get_by_uuid(api?: true) |> AsyncCsvHelper.actualize_csv_export_request()} do
      conn |> put_status(200) |> render(:csv_export, %{request: request})
    end
  end
end
