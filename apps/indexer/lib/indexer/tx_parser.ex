defmodule Indexer.TxParser do

  def raw_tx_to_cosmos_tx_hash(raw_tx) do
    Base.encode16(:crypto.hash(:sha256, elem(Base.decode64(raw_tx), 1)))
  end

  def raw_tx_to_ethereum_tx_hash(raw_txn) do
    string = raw_binary_to_string(Base.decode64!(raw_txn))
    if String.contains?(string, "/ethermint.evm.v1.MsgEthereumTx") do
      Regex.scan(~r/0x[0-9a-f]{64}/, string) |> Enum.at(0) |> Enum.at(0)
    else
      nil
    end
  end

  defp raw_binary_to_string(raw_binary) do
    codepoints = String.codepoints(raw_binary)
    Enum.reduce(codepoints,
      fn(w, result) ->
        cond do
          String.valid?(w) ->
            result <> w
          true ->
            <<parsed::8>> = w
            result <> <<parsed::utf8>>
        end
      end)
  end
end