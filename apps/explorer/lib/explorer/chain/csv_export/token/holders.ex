defmodule Explorer.Chain.CsvExport.Token.Holders do
  @moduledoc """
  Exports token holders to a csv file.
  """

  alias Explorer.Chain
  alias Explorer.Chain.{Address, CurrencyHelper, Hash, Token}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.CsvExport.AsyncHelper
  alias Explorer.Chain.CsvExport.Helper, as: CsvHelper

  @spec export(Hash.Address.t(), any(), any(), any(), any(), any()) ::
          Enumerable.t()
  def export(
        token_address_hash,
        _from_period,
        _to_period,
        _options,
        _filter_type,
        _filter_value
      ) do
    {:ok, token} = Chain.token_from_address_hash(token_address_hash, api?: true)

    token_address_hash
    |> fetch_token_holders()
    |> to_csv_format(token)
    |> CsvHelper.dump_to_stream()
  end

  defp fetch_token_holders(address_hash) do
    Chain.fetch_token_holders_from_token_hash_for_csv(address_hash,
      paging_options: CsvHelper.paging_options(),
      api?: true,
      timeout: AsyncHelper.db_timeout()
    )
  end

  @doc """
  Converts CurrentTokenBalances to CSV format. Used in `BlockScoutWeb.API.V2.CsvExportController.export_token_holders/2`
  """
  @spec to_csv_format([CurrentTokenBalance.t()], Token.t()) :: Enumerable.t()
  def to_csv_format(holders, token) do
    row_names = [
      "HolderAddress",
      "Balance"
    ]

    holders_list =
      holders
      |> Stream.map(fn ctb ->
        [
          Address.checksum(ctb.address_hash),
          ctb.value |> CurrencyHelper.divide_decimals(token.decimals) |> Decimal.to_string(:xsd)
        ]
      end)

    Stream.concat([row_names], holders_list)
  end
end
