defmodule BlockScoutWeb.CsvExportController do
  use BlockScoutWeb, :controller

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain
  alias Explorer.Chain.Address

  def index(conn, %{"address" => address_hash_string, "type" => type} = params) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string),
         :ok <- Address.check_address_exists(address_hash),
         {:ok, false} <- AccessHelper.restricted_access?(address_hash_string, params),
         true <- supported_export_type(type),
         filter_type <- Map.get(params, "filter_type"),
         filter_value <- Map.get(params, "filter_value") do
      render(conn, "index.html",
        address_hash_string: address_hash_string,
        type: type,
        filter_type: filter_type && String.downcase(filter_type),
        filter_value: filter_value && String.downcase(filter_value)
      )
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
      "logs"
    ]
  end
end
