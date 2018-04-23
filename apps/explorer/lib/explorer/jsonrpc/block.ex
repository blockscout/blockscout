defmodule Explorer.JSONRPC.Block do
  @moduledoc """
  Block format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber).
  """

  import Explorer.JSONRPC, only: [nonce_to_integer: 1, quantity_to_integer: 1, timestamp_to_datetime: 1]

  alias Explorer.JSONRPC
  alias Explorer.JSONRPC.Transactions

  # Types

  @type elixir :: %{String.t() => non_neg_integer | DateTime.t() | String.t() | nil}

  @typedoc """
  * `"author"` - `t:Explorer.JSONRPC.address/0` that created the block.  Aliased by `"miner"`.
  * `"difficulty"` - `t:Explorer.JSONRPC.quantity/0`` of the difficulty for this block.
  * `"extraData"` - the extra `t:Explorer.JSONRPC.data/0`` field of this block.
  * `"gasLimit" - maximum gas `t:Explorer.JSONRPC.quantity/0`` in this block.
  * `"gasUsed" - the total `t:Explorer.JSONRPC.quantity/0`` of gas used by all transactions in this block.
  * `"hash"` - the `t:Explorer.JSONRPC.hash/0` of the block.
  * `"logsBloom"` - `t:Explorer.JSONRPC.data/0`` for the [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter) for
      the logs of the block. `nil` when block is pending.
  * `"miner"` - `t:Explorer.JSONRPC.address/0` of the beneficiary to whom the mining rewards were given.  Aliased by
      `"author"`.
  * `"nonce"` -  `t:Explorer.JSONRPC.nonce/0`. `nil` when its pending block.
  * `"number"` - the block number `t:Explorer.JSONRPC.quantity/0`. `nil` when block is pending.
  * `"parentHash" - the `t:Explorer.JSONRPC.hash/0` of the parent block.
  * `"receiptsRoot"` - `t:Explorer.JSONRPC.hash/0` of the root of the receipts.
      [trie](https://github.com/ethereum/wiki/wiki/Patricia-Tree) of the block.
  * `"sealFields"` - UNKNOWN
  * `"sha3Uncles"` - `t:Explorer.JSONRPC.hash/0` of the
      [uncles](https://bitcoin.stackexchange.com/questions/39329/in-ethereum-what-is-an-uncle-block) data in the block.
  * `"signature"` - UNKNOWN
  * `"size"` - `t:Explorer.JSONRPC.quantity/0`` of bytes in this block
  * `"stateRoot" - `t:Explorer.JSONRPC.hash/0` of the root of the final state
      [trie](https://github.com/ethereum/wiki/wiki/Patricia-Tree) of the block.
  * `"step"` - UNKNOWN
  * `"timestamp"`: the unix timestamp as a `t:Explorer.JSONRPC.quantity/0`` for when the block was collated.
  * `"totalDifficulty" - `t:Explorer.JSONRPC.quantity/0`` of the total difficulty of the chain until this block.
  * `"transactions"` - `t:list/0` of `t:Explorer.JSONRPC.Transaction.t/0`.
  * `"transactionsRoot" - `t:Explorer.JSONRPC.hash/0` of the root of the transaction
      [trie](https://github.com/ethereum/wiki/wiki/Patricia-Tree) of the block.
  * `uncles`: `t:list/0` of
      [uncles](https://bitcoin.stackexchange.com/questions/39329/in-ethereum-what-is-an-uncle-block)
      `t:Explorer.JSONRPC.hash/0`.
  """
  @type t :: %{String.t() => JSONRPC.data() | JSONRPC.hash() | JSONRPC.quantity() | nil}

  @spec elixir_to_params(elixir) :: map
  def elixir_to_params(
        %{
          "author" => miner_hash,
          "difficulty" => difficulty,
          "gasLimit" => gas_limit,
          "gasUsed" => gas_used,
          "hash" => hash,
          "miner" => miner_hash,
          "number" => number,
          "parentHash" => parent_hash,
          "size" => size,
          "timestamp" => timestamp,
          "totalDifficulty" => total_difficulty
        } = elixir
      ) do
    %{
      difficulty: difficulty,
      gas_limit: gas_limit,
      gas_used: gas_used,
      hash: hash,
      miner_hash: miner_hash,
      number: number,
      parent_hash: parent_hash,
      size: size,
      timestamp: timestamp,
      total_difficulty: total_difficulty
    }
    |> Map.put(:nonce, Map.get(elixir, "nonce", 0))
  end

  @doc """
  Get `t:Explorer.JSONRPC.Transactions.elixir/0` from `t:elixir/0`
  """
  @spec elixir_to_transactions(elixir) :: Transactions.elixir()
  def elixir_to_transactions(%{"transactions" => transactions}), do: transactions

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0` and the timestamps to `t:DateTime.t/0`
  """
  def to_elixir(block) when is_map(block) do
    Enum.into(block, %{}, &entry_to_elixir/1)
  end

  def elixir_to_explorer_chain_block_params(elixir) when is_map(elixir) do
    Enum.into(elixir, %{}, &elixir_to_explorer_chain_block_param/1)
  end

  ## Private Functions

  defp elixir_to_explorer_chain_block_param({"difficulty", difficulty}) when is_integer(difficulty),
    do: {:difficulty, difficulty}

  defp elixir_to_explorer_chain_block_param({"gasUsed", gas_used}) when is_integer(gas_used), do: {:gas_used, gas_used}
  defp elixir_to_explorer_chain_block_param({"hash", hash}), do: {:hash, hash}
  defp elixir_to_explorer_chain_block_param({"number", number}) when is_integer(number), do: {:number, number}

  defp entry_to_elixir({key, quantity}) when key in ~w(difficulty gasLimit gasUsed number size totalDifficulty) do
    {key, quantity_to_integer(quantity)}
  end

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:Explorer.JSONRPC.address/0` and `t:Explorer.JSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format
  defp entry_to_elixir({key, _} = entry)
       when key in ~w(author extraData hash logsBloom miner parentHash receiptsRoot sealFields sha3Uncles signature
                     stateRoot step transactionsRoot uncles),
       do: entry

  defp entry_to_elixir({"nonce" = key, nonce}) do
    {key, nonce_to_integer(nonce)}
  end

  defp entry_to_elixir({"timestamp" = key, timestamp}) do
    {key, timestamp_to_datetime(timestamp)}
  end

  defp entry_to_elixir({"transactions" = key, transactions}) do
    {key, Transactions.to_elixir(transactions)}
  end
end
