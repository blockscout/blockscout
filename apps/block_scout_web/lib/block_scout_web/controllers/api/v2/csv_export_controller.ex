defmodule BlockScoutWeb.API.V2.CsvExportController do
  use BlockScoutWeb, :controller
  use OpenApiSpex.ControllerSpecs

  alias BlockScoutWeb.AccessHelper
  alias BlockScoutWeb.Schemas.API.V2.ErrorResponses.NotFoundResponse
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.CsvExport.Address.InternalTransactions, as: AddressInternalTransactionsCsvExporter
  alias Explorer.Chain.CsvExport.Address.Logs, as: AddressLogsCsvExporter
  alias Explorer.Chain.CsvExport.Address.TokenTransfers, as: AddressTokenTransfersCsvExporter
  alias Explorer.Chain.CsvExport.Address.Transactions, as: AddressTransactionsCsvExporter

  alias Explorer.Chain.CsvExport.Address.Celo.ElectionRewards,
    as: AddressCeloElectionRewardsCsvExporter

  alias Explorer.Chain.CsvExport.Helper, as: CsvHelper
  alias Plug.Conn

  import BlockScoutWeb.Chain, only: [fetch_scam_token_toggle: 2]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  plug(OpenApiSpex.Plug.CastAndValidate, json_render_error_v2: true)

  @api_true [api?: true]

  operation :export_token_holders,
    summary: "Export token holders as CSV",
    description: "Exports the holders of a specific token as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          address_id_param(),
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
           from_period: from_period,
           to_period: to_period
         } = params,
         csv_export_module
       )
       when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:address_exists, true} <- {:address_exists, Address.address_exists?(address_hash)} do
      filter_type = Map.get(params, :filter_type)
      filter_value = Map.get(params, :filter_value)

      address_hash
      |> csv_export_module.export(from_period, to_period, fetch_scam_token_toggle([], conn), filter_type, filter_value)
      |> Enum.reduce_while(put_resp_params(conn), fn chunk, conn ->
        case Conn.chunk(conn, chunk) do
          {:ok, conn} ->
            {:cont, conn}

          {:error, :closed} ->
            {:halt, conn}
        end
      end)
    else
      :error ->
        unprocessable_entity(conn)

      {:address_exists, false} ->
        not_found(conn)
    end
  end

  defp items_csv(conn, _, _), do: not_found(conn)

  operation :token_transfers_csv,
    summary: "Export token transfers as CSV",
    description: "Exports token transfers for a specific address as a CSV file.",
    parameters:
      base_params() ++
        [
          address_hash_param(),
          address_id_param(),
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
          address_id_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param()
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
          address_id_param(),
          from_period_param(),
          to_period_param(),
          filter_type_param(),
          filter_value_param()
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
          address_id_param(),
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
          address_id_param(),
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
end
