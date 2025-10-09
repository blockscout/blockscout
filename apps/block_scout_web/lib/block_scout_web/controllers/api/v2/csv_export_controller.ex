defmodule BlockScoutWeb.API.V2.CsvExportController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
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

  @api_true [api?: true]

  @doc """
  Performs CSV export of token holders for a given address
  Endpoint: `/api/v2/tokens/:address_hash_param/holders/csv`
  """
  @spec export_token_holders(Conn.t(), map()) :: Conn.t()
  def export_token_holders(conn, %{"address_hash_param" => address_hash_string} = params) do
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
           # todo: eliminate this parameter in favour address_hash_param
           "address_id" => address_hash_string,
           "from_period" => from_period,
           "to_period" => to_period
         } = params,
         csv_export_module
       )
       when is_binary(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         {:address_exists, true} <- {:address_exists, Address.address_exists?(address_hash)} do
      filter_type = Map.get(params, "filter_type")
      filter_value = Map.get(params, "filter_value")

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

  def token_transfers_csv(conn, params) do
    items_csv(conn, params, AddressTokenTransfersCsvExporter)
  end

  def transactions_csv(conn, params) do
    items_csv(conn, params, AddressTransactionsCsvExporter)
  end

  def internal_transactions_csv(conn, params) do
    items_csv(conn, params, AddressInternalTransactionsCsvExporter)
  end

  def logs_csv(conn, params) do
    items_csv(conn, params, AddressLogsCsvExporter)
  end

  @spec celo_election_rewards_csv(Conn.t(), map()) :: Conn.t()
  def celo_election_rewards_csv(conn, params) do
    items_csv(conn, params, AddressCeloElectionRewardsCsvExporter)
  end
end
