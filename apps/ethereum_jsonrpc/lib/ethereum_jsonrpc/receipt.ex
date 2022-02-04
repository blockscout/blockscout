defmodule EthereumJSONRPC.Receipt do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_gettransactionreceipt).
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.Logs

  @type elixir :: %{String.t() => String.t() | non_neg_integer}

  @typedoc """
   * `"contractAddress"` - The contract `t:EthereumJSONRPC.address/0` created, if the transaction was a contract
     creation, otherwise `nil`.
   * `"blockHash"` - `t:EthereumJSONRPC.hash/0` of the block where `"transactionHash"` was in.
   * `"blockNumber"` - The block number `t:EthereumJSONRPC.quantity/0`.
   * `"cumulativeGasUsed"` - `t:EthereumJSONRPC.quantity/0` of gas used when this transaction was executed in the
     block.
   * `"from"` - The `EthereumJSONRPC.Transaction.t/0` `"from"` address hash.  **Geth-only.**
   * `"gasUsed"` - `t:EthereumJSONRPC.quantity/0` of gas used by this specific transaction alone.
   * `"logs"` - `t:list/0` of log objects, which this transaction generated.
   * `"logsBloom"` - `t:EthereumJSONRPC.data/0` of 256 Bytes for
     [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter) for light clients to quickly retrieve related logs.
   * `"root"` - `t:EthereumJSONRPC.hash/0`  of post-transaction stateroot (pre-Byzantium)
   * `"status"` - `t:EthereumJSONRPC.quantity/0` of either 1 (success) or 0 (failure) (post-Byzantium)
   * `"to"` - The `EthereumJSONRPC.Transaction.t/0` `"to"` address hash.  **Geth-only.**
   * `"transactionHash"` - `t:EthereumJSONRPC.hash/0` the transaction.
   * `"transactionIndex"` - `t:EthereumJSONRPC.quantity/0` for the transaction index in the block.
  """
  @type t :: %{
          String.t() =>
            EthereumJSONRPC.address()
            | EthereumJSONRPC.data()
            | EthereumJSONRPC.hash()
            | EthereumJSONRPC.quantity()
            | list
            | nil
        }

  @typedoc """
   * `:ok` - transaction succeeded
   * `:error` - transaction failed
  """
  @type status :: :ok | :error

  @doc """
  Get `t:EthereumJSONRPC.Logs.elixir/0` from `t:elixir/0`
  """
  @spec elixir_to_logs(elixir) :: Logs.elixir()
  def elixir_to_logs(%{"logs" => logs}), do: logs

  @doc """
  Converts `t:elixir/0` format to params used in `Explorer.Chain`.

      iex> EthereumJSONRPC.Receipt.elixir_to_params(
      ...>   %{
      ...>     "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "blockNumber" => 34,
      ...>     "contractAddress" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>     "cumulativeGasUsed" => 269607,
      ...>     "gasUsed" => 269607,
      ...>     "logs" => [],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => :ok,
      ...>     "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> )
      %{
        created_contract_address_hash: "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
        cumulative_gas_used: 269607,
        gas_used: 269607,
        status: :ok,
        transaction_hash: "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
        transaction_index: 0
      }

  Geth, when showing pre-[Byzantium](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-609.md) does not include
  the [status](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-658.md) as that was a post-Byzantium
  [EIP](https://github.com/ethereum/EIPs/tree/master/EIPS).

  Pre-Byzantium receipts are given a `:status` of `nil`.  The `:status` can only be derived from looking at the internal
  transactions to see if there was an error.

      iex> EthereumJSONRPC.Receipt.elixir_to_params(
      ...>   %{
      ...>     "blockHash" => "0x4e3a3754410177e6937ef1f84bba68ea139e8d1a2258c5f85db9f1cd715a1bdd",
      ...>     "blockNumber" => 46147,
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => 21001,
      ...>     "from" => "0xa1e4380a3b1f749673e270229993ee55f35663b4",
      ...>     "gas" => 21001,
      ...>     "gasUsed" => 21001,
      ...>     "logs" => [],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => "0x96a8e009d2b88b1483e6941e6812e32263b05683fac202abc622a3e31aed1957",
      ...>     "to" => "0x5df9b87991262f6ba471f09758cde1c0fc1de734",
      ...>     "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
      ...>     "transactionIndex" => 0
      ...>   }
      ...> )
      %{
        created_contract_address_hash: nil,
        cumulative_gas_used: 21001,
        gas_used: 21001,
        status: nil,
        transaction_hash: "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
        transaction_index: 0
      }

  """
  @spec elixir_to_params(elixir) :: %{
          cumulative_gas_used: non_neg_integer,
          gas_used: non_neg_integer,
          created_contract_address_hash: String.t() | nil,
          status: status(),
          transaction_hash: String.t(),
          transaction_index: non_neg_integer(),
          l1_fee: non_neg_integer(),
          l1_fee_scalar: Decimal.t() | nil,
          l1_gas_price: non_neg_integer(),
          l1_gas_used: non_neg_integer()
        }
  def elixir_to_params(
        %{
          "cumulativeGasUsed" => cumulative_gas_used,
          "gasUsed" => gas_used,
          "contractAddress" => created_contract_address_hash,
          "transactionHash" => transaction_hash,
          "transactionIndex" => transaction_index,
          "l1Fee" => l1_fee,
          "l1FeeScalar" => l1_fee_scalar_string,
          "l1GasPrice" => l1_gas_price,
          "l1GasUsed" => l1_gas_used
        } = elixir
      ) do
    status = elixir_to_status(elixir)

    {l1_fee_scalar, _} =
      l1_fee_scalar_string
      |> Float.parse()

    %{
      cumulative_gas_used: cumulative_gas_used,
      gas_used: gas_used,
      created_contract_address_hash: created_contract_address_hash,
      status: status,
      transaction_hash: transaction_hash,
      transaction_index: transaction_index,
      l1_fee: l1_fee,
      l1_fee_scalar: l1_fee_scalar,
      l1_gas_price: l1_gas_price,
      l1_gas_used: l1_gas_used
    }
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.

      iex> EthereumJSONRPC.Receipt.to_elixir(
      ...>   %{
      ...>     "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "blockNumber" => "0x22",
      ...>     "contractAddress" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>     "cumulativeGasUsed" => "0x41d27",
      ...>     "gasUsed" => "0x41d27",
      ...>     "logs" => [],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => nil,
      ...>     "status" => "0x1",
      ...>     "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>     "transactionIndex" => "0x0"
      ...>   }
      ...> )
      %{
        "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
        "blockNumber" => 34,
        "contractAddress" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
        "cumulativeGasUsed" => 269607,
        "gasUsed" => 269607,
        "logs" => [],
        "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "root" => nil,
        "status" => :ok,
        "transactionHash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
        "transactionIndex" => 0
      }

  Receipts from Geth also supply the `EthereumJSONRPC.Transaction.t/0` `"from"` and `"to"` address hashes.

      iex> EthereumJSONRPC.Receipt.to_elixir(
      ...>   %{
      ...>     "blockHash" => "0x4e3a3754410177e6937ef1f84bba68ea139e8d1a2258c5f85db9f1cd715a1bdd",
      ...>     "blockNumber" => "0xb443",
      ...>     "contractAddress" => nil,
      ...>     "cumulativeGasUsed" => "0x5208",
      ...>     "from" => "0xa1e4380a3b1f749673e270229993ee55f35663b4",
      ...>     "gasUsed" => "0x5208",
      ...>     "logs" => [],
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "root" => "0x96a8e009d2b88b1483e6941e6812e32263b05683fac202abc622a3e31aed1957",
      ...>     "to" => "0x5df9b87991262f6ba471f09758cde1c0fc1de734",
      ...>     "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
      ...>     "transactionIndex" => "0x0"
      ...>   }
      ...> )
      %{
        "blockHash" => "0x4e3a3754410177e6937ef1f84bba68ea139e8d1a2258c5f85db9f1cd715a1bdd",
        "blockNumber" => 46147,
        "contractAddress" => nil,
        "cumulativeGasUsed" => 21000,
        "from" => "0xa1e4380a3b1f749673e270229993ee55f35663b4",
        "gasUsed" => 21000,
        "logs" => [],
        "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "root" => "0x96a8e009d2b88b1483e6941e6812e32263b05683fac202abc622a3e31aed1957",
        "to" => "0x5df9b87991262f6ba471f09758cde1c0fc1de734",
        "transactionHash" => "0x5c504ed432cb51138bcf09aa5e8a410dd4a1e204ef84bfed1be16dfba1b22060",
        "transactionIndex" => 0
      }

  """
  @spec to_elixir(t) :: elixir
  def to_elixir(receipt) when is_map(receipt) do
    receipt
    |> Enum.reduce({:ok, %{}}, &entry_reducer/2)
    |> ok!(receipt)
  end

  defp entry_reducer(entry, acc) do
    entry
    |> entry_to_elixir()
    |> elixir_reducer(acc)
  end

  defp elixir_reducer({:ok, {key, elixir_value}}, {:ok, elixir_map}) do
    {:ok, Map.put(elixir_map, key, elixir_value)}
  end

  defp elixir_reducer({:ok, {_, _}}, {:error, _reasons} = acc_error), do: acc_error
  defp elixir_reducer({:error, reason}, {:ok, _}), do: {:error, [reason]}
  defp elixir_reducer({:error, reason}, {:error, reasons}), do: {:error, [reason | reasons]}
  defp elixir_reducer(:ignore, acc), do: acc

  defp ok!({:ok, elixir}, _receipt), do: elixir

  defp ok!({:error, reasons}, receipt) do
    formatted_errors = Enum.map_join(reasons, "\n", fn reason -> "  #{inspect(reason)}" end)

    raise ArgumentError,
          """
          Could not convert receipt to elixir

          Receipt:
            #{inspect(receipt)}

          Errors:
          #{formatted_errors}
          """
  end

  defp elixir_to_status(%{"status" => status}), do: status
  defp elixir_to_status(_), do: nil

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:EthereumJSONRPC.address/0` and `t:EthereumJSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format
  # gas is passed in from the `t:EthereumJSONRPC.Transaction.params/0` to allow pre-Byzantium status to be derived
  defp entry_to_elixir({key, _} = entry)
       when key in ~w(blockHash contractAddress from gas logsBloom root to transactionHash revertReason type effectiveGasPrice l1FeeScalar),
       do: {:ok, entry}

  defp entry_to_elixir({key, quantity})
       when key in ~w(blockNumber cumulativeGasUsed gasUsed transactionIndex l1Fee l1GasPrice l1GasUsed) do
    result =
      if is_nil(quantity) do
        nil
      else
        quantity_to_integer(quantity)
      end

    {:ok, {key, result}}
  end

  defp entry_to_elixir({"logs" = key, logs}) do
    {:ok, {key, Logs.to_elixir(logs)}}
  end

  defp entry_to_elixir({"status" = key, status}) do
    case status do
      zero when zero in ["0x0", "0x00"] ->
        {:ok, {key, :error}}

      one when one in ["0x1", "0x01"] ->
        {:ok, {key, :ok}}

      # pre-Byzantium / Ethereum Classic on Parity
      nil ->
        :ignore

      other ->
        {:error, {:unknown_value, %{key: key, value: other}}}
    end
  end

  # fixes for latest ganache JSON RPC
  defp entry_to_elixir({key, _}) when key in ~w(r s v) do
    :ignore
  end

  # Nethermind field
  defp entry_to_elixir({"error", _}) do
    :ignore
  end

  # Arbitrum fields
  defp entry_to_elixir({key, _}) when key in ~w(returnData returnCode feeStats) do
    :ignore
  end

  defp entry_to_elixir({key, value}) do
    {:error, {:unknown_key, %{key: key, value: value}}}
  end
end
