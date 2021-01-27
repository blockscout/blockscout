defmodule BlockScoutWeb.CsvExportView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Chain.Address

  defp type_display_name(type) do
    case type do
      "internal-transactions" -> "internal transactions"
      "transactions" -> "transactions"
      "token-transfers" -> "token transfers"
      "logs" -> "logs"
      _ -> ""
    end
  end

  defp type_download_path(type) do
    case type do
      "internal-transactions" -> :internal_transactions_csv
      "transactions" -> :transactions_csv
      "token-transfers" -> :token_transfers_csv
      "logs" -> :logs_csv
      _ -> ""
    end
  end

  defp address_checksum(address_hash_string) do
    with {:ok, address_hash} <- Chain.string_to_address_hash(address_hash_string) do
      address_hash
      |> Address.checksum()
    end
  end

  defp default_period_start do
    DateTime.utc_now()
    |> Timex.shift(months: -3)
    |> Timex.format!("{YYYY}-{0M}-{0D}")
  end

  defp default_period_end do
    DateTime.utc_now()
    |> Timex.format!("{YYYY}-{0M}-{0D}")
  end
end
