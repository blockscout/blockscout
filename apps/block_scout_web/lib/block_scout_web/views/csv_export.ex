defmodule BlockScoutWeb.CsvExportView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Controller, as: BlockScoutWebController
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Explorer.Chain.CSVExport.Helper

  defp type_display_name(type) do
    case type do
      "internal-transactions" -> "internal transactions"
      "transactions" -> "transactions"
      "token-transfers" -> "token transfers"
      "logs" -> "logs"
      _ -> ""
    end
  end

  defp type_download_path(nil), do: ""

  defp type_download_path(type) do
    type <> "-csv"
  end

  defp address_checksum(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      address_hash
      |> Address.checksum()
    end
  end
end
