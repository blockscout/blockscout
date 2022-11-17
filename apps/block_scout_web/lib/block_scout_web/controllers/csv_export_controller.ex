defmodule BlockScoutWeb.CsvExportController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelpers
  alias Explorer.Chain

  def index(conn, %{"address" => address_hash_string, "type" => type} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Chain.check_address_exists(address_hash),
         {:ok, false} <- AccessHelpers.restricted_access?(address_hash_string, params),
         true <- supported_export_type(type) do
      render(conn, "index.html", address_hash_string: address_hash_string, type: type)
    else
      _ ->
        not_found(conn)
    end
  end

  def index(conn, _params) do
    not_found(conn)
  end

  defp supported_export_type(type) do
    Enum.member?(supported_types(), type)
  end

  defp supported_types do
    [
      "internal-transactions",
      "transactions",
      "token-transfers",
      "logs",
      "epoch-transactions"
    ]
  end
end
