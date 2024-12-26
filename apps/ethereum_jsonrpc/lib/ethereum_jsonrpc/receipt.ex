defmodule EthereumJSONRPC.Receipt do
  @moduledoc """
  Receipts format as returned by
  [`eth_getTransactionReceipt`](https://github.com/ethereum/wiki/wiki/JSON-RPC/e8e0771b9f3677693649d945956bc60e886ceb2b#eth_gettransactionreceipt).
  """
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  alias EthereumJSONRPC.Logs

  case @chain_type do
    :ethereum ->
      @chain_type_fields quote(
                           do: [
                             blob_gas_price: non_neg_integer(),
                             blob_gas_used: non_neg_integer()
                           ]
                         )

    :optimism ->
      @chain_type_fields quote(
                           do: [
                             l1_fee: non_neg_integer(),
                             l1_fee_scalar: non_neg_integer(),
                             l1_gas_price: non_neg_integer(),
                             l1_gas_used: non_neg_integer()
                           ]
                         )

    :scroll ->
      @chain_type_fields quote(
                           do: [
                             l1_fee: non_neg_integer()
                           ]
                         )

    :arbitrum ->
      @chain_type_fields quote(
                           do: [
                             gas_used_for_l1: non_neg_integer()
                           ]
                         )

    _ ->
      @chain_type_fields quote(do: [])
  end

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

  @type params :: %{
          unquote_splicing(@chain_type_fields),
          optional(:gas_price) => non_neg_integer(),
          cumulative_gas_used: non_neg_integer(),
          gas_used: non_neg_integer(),
          created_contract_address_hash: EthereumJSONRPC.hash(),
          status: :ok | :error,
          transaction_hash: EthereumJSONRPC.hash(),
          transaction_index: non_neg_integer()
        }

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
        transaction_index: 0,\
  #{case @chain_type do
    :ethereum -> """
            blob_gas_price: 0,\
            blob_gas_used: 0\
      """
    :optimism -> """
          l1_fee: 0,\
          l1_fee_scalar: 0,\
          l1_gas_price: 0,\
          l1_gas_used: 0\
      """
    :scroll -> """
          l1_fee: 0\
      """
    :arbitrum -> """
          gas_used_for_l1: nil\
      """
    _ -> ""
  end}
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
        transaction_index: 0,\
  #{case @chain_type do
    :ethereum -> """
            blob_gas_price: 0,\
            blob_gas_used: 0\
      """
    :optimism -> """
          l1_fee: 0,\
          l1_fee_scalar: 0,\
          l1_gas_price: 0,\
          l1_gas_used: 0\
      """
    :scroll -> """
          l1_fee: 0\
      """
    :arbitrum -> """
          gas_used_for_l1: nil\
      """
    _ -> ""
  end}
      }

  """
  @spec elixir_to_params(elixir) :: params
  def elixir_to_params(elixir) do
    elixir
    |> do_elixir_to_params()
    |> chain_type_fields(elixir)
  end

  def do_elixir_to_params(
        %{
          "cumulativeGasUsed" => cumulative_gas_used,
          "gasUsed" => gas_used,
          "contractAddress" => created_contract_address_hash,
          "transactionHash" => transaction_hash,
          "transactionIndex" => transaction_index
        } = elixir
      ) do
    status = elixir_to_status(elixir)

    %{
      cumulative_gas_used: cumulative_gas_used,
      gas_used: gas_used,
      created_contract_address_hash: created_contract_address_hash,
      status: status,
      transaction_hash: transaction_hash,
      transaction_index: transaction_index
    }
    |> maybe_append_gas_price(elixir)
  end

  defp maybe_append_gas_price(params, %{"effectiveGasPrice" => effective_gas_price}) do
    if is_nil(effective_gas_price) do
      params
    else
      Map.put(params, :gas_price, effective_gas_price)
    end
  end

  defp maybe_append_gas_price(params, _), do: params

  case @chain_type do
    :ethereum ->
      defp chain_type_fields(params, elixir) do
        params
        |> Map.merge(%{
          blob_gas_price: Map.get(elixir, "blobGasPrice", 0),
          blob_gas_used: Map.get(elixir, "blobGasUsed", 0)
        })
      end

    :optimism ->
      defp chain_type_fields(params, elixir) do
        params
        |> Map.merge(%{
          l1_fee: Map.get(elixir, "l1Fee", 0),
          l1_fee_scalar: Map.get(elixir, "l1FeeScalar", 0),
          l1_gas_price: Map.get(elixir, "l1GasPrice", 0),
          l1_gas_used: Map.get(elixir, "l1GasUsed", 0)
        })
      end

    :scroll ->
      defp chain_type_fields(params, elixir) do
        params
        |> Map.merge(%{
          l1_fee: Map.get(elixir, "l1Fee", 0)
        })
      end

    :arbitrum ->
      defp chain_type_fields(params, elixir) do
        params
        |> Map.merge(%{
          gas_used_for_l1: Map.get(elixir, "gasUsedForL1")
        })
      end

    _ ->
      defp chain_type_fields(params, _), do: params
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
       when key in ~w(blockHash contractAddress from gas logsBloom root to transactionHash
                      revertReason type l1FeeScalar),
       do: {:ok, entry}

  defp entry_to_elixir({key, quantity})
       when key in ~w(blockNumber cumulativeGasUsed gasUsed transactionIndex blobGasUsed
                      blobGasPrice l1Fee l1GasPrice l1GasUsed effectiveGasPrice gasUsedForL1
                      l1BlobBaseFeeScalar l1BlobBaseFee l1BaseFeeScalar) do
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

      # pre-Byzantium
      nil ->
        :ignore

      other ->
        {:error, {:unknown_value, %{key: key, value: other}}}
    end
  end

  defp entry_to_elixir({_, _}) do
    :ignore
  end
end
