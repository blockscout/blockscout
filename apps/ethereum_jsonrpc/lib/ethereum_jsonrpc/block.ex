defmodule EthereumJSONRPC.Block do
  @moduledoc """
  Block format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber).
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1, timestamp_to_datetime: 1]

  alias EthereumJSONRPC.{Transactions, Uncles}

  @type elixir :: %{String.t() => non_neg_integer | DateTime.t() | String.t() | nil}
  @type params :: %{
          difficulty: pos_integer(),
          extra_data: EthereumJSONRPC.hash(),
          gas_limit: non_neg_integer(),
          gas_used: non_neg_integer(),
          hash: EthereumJSONRPC.hash(),
          logs_bloom: EthereumJSONRPC.hash(),
          miner_hash: EthereumJSONRPC.hash(),
          mix_hash: EthereumJSONRPC.hash(),
          nonce: EthereumJSONRPC.hash(),
          number: non_neg_integer(),
          parent_hash: EthereumJSONRPC.hash(),
          receipts_root: EthereumJSONRPC.hash(),
          sha3_uncles: EthereumJSONRPC.hash(),
          size: non_neg_integer(),
          state_root: EthereumJSONRPC.hash(),
          timestamp: DateTime.t(),
          total_difficulty: non_neg_integer(),
          transactions_root: EthereumJSONRPC.hash(),
          uncles: [EthereumJSONRPC.hash()],
          base_fee_per_gas: non_neg_integer()
        }

  @typedoc """
   * `"author"` - `t:EthereumJSONRPC.address/0` that created the block.  Aliased by `"miner"`.
   * `"difficulty"` - `t:EthereumJSONRPC.quantity/0` of the difficulty for this block.
   * `"extraData"` - the extra `t:EthereumJSONRPC.data/0` field of this block.
   * `"gasLimit" - maximum gas `t:EthereumJSONRPC.quantity/0` in this block.
   * `"gasUsed" - the total `t:EthereumJSONRPC.quantity/0` of gas used by all transactions in this block.
   * `"hash"` - the `t:EthereumJSONRPC.hash/0` of the block.
   * `"logsBloom"` - `t:EthereumJSONRPC.data/0` for the [Bloom filter](https://en.wikipedia.org/wiki/Bloom_filter)
     for the logs of the block. `nil` when block is pending.
   * `"miner"` - `t:EthereumJSONRPC.address/0` of the beneficiary to whom the mining rewards were given.  Aliased by
      `"author"`.
   * `"mixHash"` - Generated from [DAG](https://ethereum.stackexchange.com/a/10353) as part of Proof-of-Work for EthHash
     algorithm.  **[Geth](https://github.com/ethereum/go-ethereum/wiki/geth) + Proof-of-Work-only**
   * `"nonce"` -  `t:EthereumJSONRPC.nonce/0`. `nil` when its pending block.
   * `"number"` - the block number `t:EthereumJSONRPC.quantity/0`. `nil` when block is pending.
   * `"parentHash" - the `t:EthereumJSONRPC.hash/0` of the parent block.
   * `"receiptsRoot"` - `t:EthereumJSONRPC.hash/0` of the root of the receipts.
     [trie](https://github.com/ethereum/wiki/wiki/Patricia-Tree) of the block.
   * `"sealFields"` - UNKNOWN
   * `"sha3Uncles"` - `t:EthereumJSONRPC.hash/0` of the
     [uncles](https://bitcoin.stackexchange.com/questions/39329/in-ethereum-what-is-an-uncle-block) data in the block.
   * `"signature"` - UNKNOWN
   * `"size"` - `t:EthereumJSONRPC.quantity/0` of bytes in this block
   * `"stateRoot" - `t:EthereumJSONRPC.hash/0` of the root of the final state
     [trie](https://github.com/ethereum/wiki/wiki/Patricia-Tree) of the block.
   * `"step"` - UNKNOWN
   * `"timestamp"`: the unix timestamp as a `t:EthereumJSONRPC.quantity/0` for when the block was collated.
   * `"totalDifficulty" - `t:EthereumJSONRPC.quantity/0` of the total difficulty of the chain until this block.
   * `"transactions"` - `t:list/0` of `t:EthereumJSONRPC.Transaction.t/0`.
   * `"transactionsRoot" - `t:EthereumJSONRPC.hash/0` of the root of the transaction
     [trie](https://github.com/ethereum/wiki/wiki/Patricia-Tree) of the block.
   * `uncles`: `t:list/0` of
     [uncles](https://bitcoin.stackexchange.com/questions/39329/in-ethereum-what-is-an-uncle-block)
     `t:EthereumJSONRPC.hash/0`.
   * `"baseFeePerGas"` - `t:EthereumJSONRPC.quantity/0` of wei to denote amount of fee burned per unit gas used. Introduced in [EIP-1559](https://github.com/ethereum/EIPs/blob/master/EIPS/eip-1559.md)
  """
  @type t :: %{String.t() => EthereumJSONRPC.data() | EthereumJSONRPC.hash() | EthereumJSONRPC.quantity() | nil}

  def from_response(%{id: id, result: nil}, id_to_params) when is_map(id_to_params) do
    params = Map.fetch!(id_to_params, id)

    {:error, %{code: 404, message: "Not Found", data: params}}
  end

  def from_response(%{id: id, result: block}, id_to_params) when is_map(id_to_params) do
    true = Map.has_key?(id_to_params, id)

    {:ok, block}
  end

  def from_response(%{id: id, error: error}, id_to_params) when is_map(id_to_params) do
    params = Map.fetch!(id_to_params, id)
    annotated_error = Map.put(error, :data, params)

    {:error, annotated_error}
  end

  @doc """
  Converts `t:elixir/0` format to params used in `Explorer.Chain`.

      iex> EthereumJSONRPC.Block.elixir_to_params(
      ...>   %{
      ...>     "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "difficulty" => 340282366920938463463374607431465537093,
      ...>     "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
      ...>     "gasLimit" => 6706541,
      ...>     "gasUsed" => 0,
      ...>     "hash" => "0x52c867bc0a91e573dc39300143c3bead7408d09d45bdb686749f02684ece72f3",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "number" => 1,
      ...>     "parentHash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
      ...>     "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "sealFields" => [
      ...>       "0x84120a71ba",
      ...>       "0xb8417a5887662f09ac4673af5850d28f3ad6550407b9c814ef563a13320f881b55ef03754f48f2dde027ad4a5abcabcc42780d9ebfc645f183e5252507d6a25bc2ec01"
      ...>     ],
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "signature" => "7a5887662f09ac4673af5850d28f3ad6550407b9c814ef563a13320f881b55ef03754f48f2dde027ad4a5abcabcc42780d9ebfc645f183e5252507d6a25bc2ec01",
      ...>     "size" => 576,
      ...>     "stateRoot" => "0xc196ad59d867542ef20b29df5f418d07dc7234f4bc3d25260526620b7958a8fb",
      ...>     "step" => "302674362",
      ...>     "timestamp" => Timex.parse!("2017-12-15T21:03:30Z", "{ISO:Extended:Z}"),
      ...>     "totalDifficulty" => 340282366920938463463374607431465668165,
      ...>     "transactions" => [],
      ...>     "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "uncles" => []
      ...>   }
      ...> )
      %{
        difficulty: 340282366920938463463374607431465537093,
        extra_data: "0xd5830108048650617269747986312e32322e31826c69",
        gas_limit: 6706541,
        gas_used: 0,
        hash: "0x52c867bc0a91e573dc39300143c3bead7408d09d45bdb686749f02684ece72f3",
        logs_bloom: "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        miner_hash: "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
        mix_hash: "0x0",
        nonce: 0,
        number: 1,
        parent_hash: "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
        receipts_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        sha3_uncles: "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        size: 576,
        state_root: "0xc196ad59d867542ef20b29df5f418d07dc7234f4bc3d25260526620b7958a8fb",
        timestamp: Timex.parse!("2017-12-15T21:03:30Z", "{ISO:Extended:Z}"),
        total_difficulty: 340282366920938463463374607431465668165,
        transactions_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        uncles: []
      }

  [Geth] `elixir` can be converted to params

      iex> EthereumJSONRPC.Block.elixir_to_params(
      ...>   %{
      ...>     "difficulty" => 17561410778,
      ...>     "extraData" => "0x476574682f4c5649562f76312e302e302f6c696e75782f676f312e342e32",
      ...>     "gasLimit" => 5000,
      ...>     "gasUsed" => 0,
      ...>     "hash" => "0x4d9423080290a650eaf6db19c87c76dff83d1b4ab64aefe6e5c5aa2d1f4b6623",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xbb7b8287f3f0a933474a79eae42cbca977791171",
      ...>     "mixHash" => "0xbbb93d610b2b0296a59f18474ac3d6086a9902aa7ca4b9a306692f7c3d496fdf",
      ...>     "nonce" => 5539500215739777653,
      ...>     "number" => 59,
      ...>     "parentHash" => "0xcd5b5c4cecd7f18a13fe974255badffd58e737dc67596d56bc01f063dd282e9e",
      ...>     "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "size" => 542,
      ...>     "stateRoot" => "0x6fd0a5d82ca77d9f38c3ebbde11b11d304a5fcf3854f291df64395ab38ed43ba",
      ...>     "timestamp" => Timex.parse!("2015-07-30T15:32:07Z", "{ISO:Extended:Z}"),
      ...>     "totalDifficulty" => 1039309006117,
      ...>     "transactions" => [],
      ...>     "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "uncles" => []
      ...>   }
      ...> )
      %{
        difficulty: 17561410778,
        extra_data: "0x476574682f4c5649562f76312e302e302f6c696e75782f676f312e342e32",
        gas_limit: 5000,
        gas_used: 0,
        hash: "0x4d9423080290a650eaf6db19c87c76dff83d1b4ab64aefe6e5c5aa2d1f4b6623",
        logs_bloom: "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        mix_hash: "0xbbb93d610b2b0296a59f18474ac3d6086a9902aa7ca4b9a306692f7c3d496fdf",
        miner_hash: "0xbb7b8287f3f0a933474a79eae42cbca977791171",
        nonce: 5539500215739777653,
        number: 59,
        parent_hash: "0xcd5b5c4cecd7f18a13fe974255badffd58e737dc67596d56bc01f063dd282e9e",
        receipts_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        sha3_uncles: "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        size: 542,
        state_root: "0x6fd0a5d82ca77d9f38c3ebbde11b11d304a5fcf3854f291df64395ab38ed43ba",
        timestamp: Timex.parse!("2015-07-30T15:32:07Z", "{ISO:Extended:Z}"),
        total_difficulty: 1039309006117,
        transactions_root: "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        uncles: []
      }

  """
  @spec elixir_to_params(elixir) :: params
  def elixir_to_params(
        %{
          "difficulty" => difficulty,
          "extraData" => extra_data,
          "gasLimit" => gas_limit,
          "gasUsed" => gas_used,
          "hash" => hash,
          "logsBloom" => logs_bloom,
          "miner" => miner_hash,
          "number" => number,
          "parentHash" => parent_hash,
          "receiptsRoot" => receipts_root,
          "sha3Uncles" => sha3_uncles,
          "size" => size,
          "stateRoot" => state_root,
          "timestamp" => timestamp,
          "totalDifficulty" => total_difficulty,
          "transactionsRoot" => transactions_root,
          "uncles" => uncles,
          "baseFeePerGas" => base_fee_per_gas
        } = elixir
      ) do
    %{
      difficulty: difficulty,
      extra_data: extra_data,
      gas_limit: gas_limit,
      gas_used: gas_used,
      hash: hash,
      logs_bloom: logs_bloom,
      miner_hash: miner_hash,
      mix_hash: Map.get(elixir, "mixHash", "0x0"),
      nonce: Map.get(elixir, "nonce", 0),
      number: number,
      parent_hash: parent_hash,
      receipts_root: receipts_root,
      sha3_uncles: sha3_uncles,
      size: size,
      state_root: state_root,
      timestamp: timestamp,
      total_difficulty: total_difficulty,
      transactions_root: transactions_root,
      uncles: uncles,
      base_fee_per_gas: base_fee_per_gas
    }
  end

  def elixir_to_params(
        %{
          "difficulty" => difficulty,
          "extraData" => extra_data,
          "gasLimit" => gas_limit,
          "gasUsed" => gas_used,
          "hash" => hash,
          "logsBloom" => logs_bloom,
          "miner" => miner_hash,
          "number" => number,
          "parentHash" => parent_hash,
          "receiptsRoot" => receipts_root,
          "sha3Uncles" => sha3_uncles,
          "size" => size,
          "stateRoot" => state_root,
          "timestamp" => timestamp,
          "transactionsRoot" => transactions_root,
          "uncles" => uncles,
          "baseFeePerGas" => base_fee_per_gas
        } = elixir
      ) do
    %{
      difficulty: difficulty,
      extra_data: extra_data,
      gas_limit: gas_limit,
      gas_used: gas_used,
      hash: hash,
      logs_bloom: logs_bloom,
      miner_hash: miner_hash,
      mix_hash: Map.get(elixir, "mixHash", "0x0"),
      nonce: Map.get(elixir, "nonce", 0),
      number: number,
      parent_hash: parent_hash,
      receipts_root: receipts_root,
      sha3_uncles: sha3_uncles,
      size: size,
      state_root: state_root,
      timestamp: timestamp,
      transactions_root: transactions_root,
      uncles: uncles,
      base_fee_per_gas: base_fee_per_gas
    }
  end

  def elixir_to_params(
        %{
          "difficulty" => difficulty,
          "extraData" => extra_data,
          "gasLimit" => gas_limit,
          "gasUsed" => gas_used,
          "hash" => hash,
          "logsBloom" => logs_bloom,
          "miner" => miner_hash,
          "number" => number,
          "parentHash" => parent_hash,
          "receiptsRoot" => receipts_root,
          "sha3Uncles" => sha3_uncles,
          "size" => size,
          "stateRoot" => state_root,
          "timestamp" => timestamp,
          "totalDifficulty" => total_difficulty,
          "transactionsRoot" => transactions_root,
          "uncles" => uncles
        } = elixir
      ) do
    %{
      difficulty: difficulty,
      extra_data: extra_data,
      gas_limit: gas_limit,
      gas_used: gas_used,
      hash: hash,
      logs_bloom: logs_bloom,
      miner_hash: miner_hash,
      mix_hash: Map.get(elixir, "mixHash", "0x0"),
      nonce: Map.get(elixir, "nonce", 0),
      number: number,
      parent_hash: parent_hash,
      receipts_root: receipts_root,
      sha3_uncles: sha3_uncles,
      size: size,
      state_root: state_root,
      timestamp: timestamp,
      total_difficulty: total_difficulty,
      transactions_root: transactions_root,
      uncles: uncles
    }
  end

  # Geth: a response from eth_getblockbyhash for uncle blocks is without `totalDifficulty` param
  def elixir_to_params(
        %{
          "difficulty" => difficulty,
          "extraData" => extra_data,
          "gasLimit" => gas_limit,
          "gasUsed" => gas_used,
          "hash" => hash,
          "logsBloom" => logs_bloom,
          "miner" => miner_hash,
          "number" => number,
          "parentHash" => parent_hash,
          "receiptsRoot" => receipts_root,
          "sha3Uncles" => sha3_uncles,
          "size" => size,
          "stateRoot" => state_root,
          "timestamp" => timestamp,
          "transactionsRoot" => transactions_root,
          "uncles" => uncles
        } = elixir
      ) do
    %{
      difficulty: difficulty,
      extra_data: extra_data,
      gas_limit: gas_limit,
      gas_used: gas_used,
      hash: hash,
      logs_bloom: logs_bloom,
      miner_hash: miner_hash,
      mix_hash: Map.get(elixir, "mixHash", "0x0"),
      nonce: Map.get(elixir, "nonce", 0),
      number: number,
      parent_hash: parent_hash,
      receipts_root: receipts_root,
      sha3_uncles: sha3_uncles,
      size: size,
      state_root: state_root,
      timestamp: timestamp,
      transactions_root: transactions_root,
      uncles: uncles
    }
  end

  @doc """
  Get `t:EthereumJSONRPC.Transactions.elixir/0` from `t:elixir/0`

      iex> EthereumJSONRPC.Block.elixir_to_transactions(
      ...>   %{
      ...>     "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "difficulty" => 340282366920938463463374607431768211454,
      ...>     "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
      ...>     "gasLimit" => 6926030,
      ...>     "gasUsed" => 269607,
      ...>     "hash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "number" => 34,
      ...>     "parentHash" => "0x106d528393159b93218dd410e2a778f083538098e46f1a44902aa67a164aed0b",
      ...>     "receiptsRoot" => "0xf45ed4ab910504ffe231230879c86e32b531bb38a398a7c9e266b4a992e12dfb",
      ...>     "sealFields" => [
      ...>       "0x84120a71db",
      ...>       "0xb8417ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501"
      ...>     ],
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "signature" => "7ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501",
      ...>     "size" => 1493,
      ...>     "stateRoot" => "0x6eaa6281df37b9b010f4779affc25ee059088240547ce86cf7ca7b7acd952d4f",
      ...>     "step" => "302674395",
      ...>     "timestamp" => Timex.parse!("2017-12-15T21:06:15Z", "{ISO:Extended:Z}"),
      ...>     "totalDifficulty" => 11569600475311907757754736652679816646147,
      ...>     "transactions" => [
      ...>       %{
      ...>         "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>         "blockNumber" => 34,
      ...>         "chainId" => 77,
      ...>         "condition" => nil,
      ...>         "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
      ...>         "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>         "gas" => 4700000,
      ...>         "gasPrice" => 100000000000,
      ...>         "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
      ...>         "input" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>         "nonce" => 0,
      ...>         "publicKey" => "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
      ...>         "r" => 78347657398501398198088841525118387115323315106407672963464534626150881627253,
      ...>         "raw" => "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
      ...>         "s" => 51922098313630537482394298802395571009347262093735654389129912200586195014115,
      ...>         "standardV" => 0,
      ...>         "to" => nil,
      ...>         "transactionIndex" => 0,
      ...>         "v" => 189,
      ...>         "value" => 0
      ...>       }
      ...>     ],
      ...>     "transactionsRoot" => "0x2c2e243e9735f6d0081ffe60356c0e4ec4c6a9064c68d10bf8091ff896f33087",
      ...>     "uncles" => []
      ...>   }
      ...> )
      [
        %{
          "blockHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
          "blockNumber" => 34,
          "chainId" => 77,
          "condition" => nil,
          "creates" => "0xffc87239eb0267bc3ca2cd51d12fbf278e02ccb4",
          "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
          "gas" => 4700000,
          "gasPrice" => 100000000000,
          "hash" => "0x3a3eb134e6792ce9403ea4188e5e79693de9e4c94e499db132be086400da79e6",
          "input" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
          "nonce" => 0,
          "publicKey" => "0xe5d196ad4ceada719d9e592f7166d0c75700f6eab2e3c3de34ba751ea786527cb3f6eb96ad9fdfdb9989ff572df50f1c42ef800af9c5207a38b929aff969b5c9",
          "r" => 78347657398501398198088841525118387115323315106407672963464534626150881627253,
          "raw" => "0xf9038d8085174876e8008347b7608080b903396060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b002981bda0ad3733df250c87556335ffe46c23e34dbaffde93097ef92f52c88632a40f0c75a072caddc0371451a58de2ca6ab64e0f586ccdb9465ff54e1c82564940e89291e3",
          "s" => 51922098313630537482394298802395571009347262093735654389129912200586195014115,
          "standardV" => 0,
          "to" => nil,
          "transactionIndex" => 0,
          "v" => 189,
          "value" => 0
        }
      ]

  """
  @spec elixir_to_transactions(elixir) :: Transactions.elixir()
  def elixir_to_transactions(%{"transactions" => transactions}), do: transactions

  def elixir_to_transactions(_), do: []

  @doc """
  Get `t:EthereumJSONRPC.Uncles.elixir/0` from `t:elixir/0`.

  Because an uncle can have multiple nephews, the `t:elixir/0` `"hash"` value is included as the `"nephewHash"` value.

      iex> EthereumJSONRPC.Block.elixir_to_uncles(
      ...>   %{
      ...>     "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "difficulty" => 340282366920938463463374607431768211454,
      ...>     "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
      ...>     "gasLimit" => 6926030,
      ...>     "gasUsed" => 269607,
      ...>     "hash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "number" => 34,
      ...>     "parentHash" => "0x106d528393159b93218dd410e2a778f083538098e46f1a44902aa67a164aed0b",
      ...>     "receiptsRoot" => "0xf45ed4ab910504ffe231230879c86e32b531bb38a398a7c9e266b4a992e12dfb",
      ...>     "sealFields" => [
      ...>       "0x84120a71db",
      ...>       "0xb8417ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501"
      ...>     ],
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "signature" => "7ad0ecca535f81e1807dac338a57c7ccffd05d3e7f0687944650cd005360a192205df306a68eddfe216e0674c6b113050d90eff9b627c1762d43657308f986f501",
      ...>     "size" => 1493,
      ...>     "stateRoot" => "0x6eaa6281df37b9b010f4779affc25ee059088240547ce86cf7ca7b7acd952d4f",
      ...>     "step" => "302674395",
      ...>     "timestamp" => Timex.parse!("2017-12-15T21:06:15Z", "{ISO:Extended:Z}"),
      ...>     "totalDifficulty" => 11569600475311907757754736652679816646147,
      ...>     "transactions" => [],
      ...>     "transactionsRoot" => "0x2c2e243e9735f6d0081ffe60356c0e4ec4c6a9064c68d10bf8091ff896f33087",
      ...>     "uncles" => ["0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311"]
      ...>   }
      ...> )
      [
        %{
          "hash" => "0xe670ec64341771606e55d6b4ca35a1a6b75ee3d5145a99d05921026d15273311",
          "nephewHash" => "0xe52d77084cab13a4e724162bcd8c6028e5ecfaa04d091ee476e96b9958ed6b47",
          "index" => 0
        }
      ]

  """
  @spec elixir_to_uncles(elixir) :: Uncles.elixir()
  def elixir_to_uncles(%{"hash" => nephew_hash, "uncles" => uncles}) do
    uncles
    |> Enum.with_index()
    |> Enum.map(fn {uncle_hash, index} -> %{"hash" => uncle_hash, "nephewHash" => nephew_hash, "index" => index} end)
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0` and the timestamps to `t:DateTime.t/0`

      iex> EthereumJSONRPC.Block.to_elixir(
      ...>   %{
      ...>     "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "difficulty" => "0xfffffffffffffffffffffffffffffffe",
      ...>     "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
      ...>     "gasLimit" => "0x66889b",
      ...>     "gasUsed" => "0x0",
      ...>     "hash" => "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
      ...>     "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>     "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "number" => "0x3",
      ...>     "parentHash" => "0x5fc539c74f65418c64df413c8cc89828c4657a9fecabaa550ceb44ec67786da7",
      ...>     "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "sealFields" => [
      ...>     "0x84120a71bc",
      ...>     "0xb84116ffce67521cd71e44f9c101a9018020fb296c8c3478a17142d7146aafbb189b3c75e0e554d10f6dd7e4dc4567471e673a957cfcb690c37ca65fafa9ade4455101"
      ...>     ],
      ...>     "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>     "signature" => "16ffce67521cd71e44f9c101a9018020fb296c8c3478a17142d7146aafbb189b3c75e0e554d10f6dd7e4dc4567471e673a957cfcb690c37ca65fafa9ade4455101",
      ...>     "size" => "0x240",
      ...>     "stateRoot" => "0xf0a110ed0f3173dfb2403c59f4f7971ad3be5ec4eedee0764bd654d607213aba",
      ...>     "step" => "302674364",
      ...>     "timestamp" => "0x5a3438ac",
      ...>     "totalDifficulty" => "0x2ffffffffffffffffffffffffedf78e41",
      ...>     "transactions" => [],
      ...>     "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>     "uncles" => []
      ...>   }
      ...> )
      %{
        "author" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
        "difficulty" => 340282366920938463463374607431768211454,
        "extraData" => "0xd5830108048650617269747986312e32322e31826c69",
        "gasLimit" => 6719643,
        "gasUsed" => 0,
        "hash" => "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
        "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
        "miner" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
        "number" => 3,
        "parentHash" => "0x5fc539c74f65418c64df413c8cc89828c4657a9fecabaa550ceb44ec67786da7",
        "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "sealFields" => [
          "0x84120a71bc",
          "0xb84116ffce67521cd71e44f9c101a9018020fb296c8c3478a17142d7146aafbb189b3c75e0e554d10f6dd7e4dc4567471e673a957cfcb690c37ca65fafa9ade4455101"
        ],
        "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
        "signature" => "16ffce67521cd71e44f9c101a9018020fb296c8c3478a17142d7146aafbb189b3c75e0e554d10f6dd7e4dc4567471e673a957cfcb690c37ca65fafa9ade4455101",
        "size" => 576,
        "stateRoot" => "0xf0a110ed0f3173dfb2403c59f4f7971ad3be5ec4eedee0764bd654d607213aba",
        "step" => "302674364",
        "timestamp" => Timex.parse!("2017-12-15T21:03:40Z", "{ISO:Extended:Z}"),
        "totalDifficulty" => 1020847100762815390390123822295002091073,
        "transactions" => [],
        "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
        "uncles" => []
      }

  """
  def to_elixir(block) when is_map(block) do
    Enum.into(block, %{}, &entry_to_elixir/1)
  end

  defp entry_to_elixir({key, quantity})
       when key in ~w(difficulty gasLimit gasUsed minimumGasPrice baseFeePerGas number size cumulativeDifficulty totalDifficulty paidFees) and
              not is_nil(quantity) do
    {key, quantity_to_integer(quantity)}
  end

  # Size and totalDifficulty may be `nil` for uncle blocks
  defp entry_to_elixir({key, nil}) when key in ~w(size totalDifficulty) do
    {key, nil}
  end

  # double check that no new keys are being missed by requiring explicit match for passthrough
  # `t:EthereumJSONRPC.address/0` and `t:EthereumJSONRPC.hash/0` pass through as `Explorer.Chain` can verify correct
  # hash format
  # bitcoinMergedMiningCoinbaseTransaction bitcoinMergedMiningHeader bitcoinMergedMiningMerkleProof hashForMergedMining - RSK https://github.com/blockscout/blockscout/pull/2934
  # committedSeals committee pastCommittedSeals proposerSeal round - Autonity network https://github.com/blockscout/blockscout/pull/3480
  # blockGasCost extDataGasUsed - sgb/ava https://github.com/blockscout/blockscout/pull/5301
  defp entry_to_elixir({key, _} = entry)
       when key in ~w(author extraData hash logsBloom miner mixHash nonce parentHash receiptsRoot sealFields sha3Uncles
                     signature stateRoot step transactionsRoot uncles bitcoinMergedMiningCoinbaseTransaction bitcoinMergedMiningHeader bitcoinMergedMiningMerkleProof hashForMergedMining committedSeals committee pastCommittedSeals proposerSeal round blockGasCost extDataGasUsed),
       do: entry

  defp entry_to_elixir({"timestamp" = key, timestamp}) do
    {key, timestamp_to_datetime(timestamp)}
  end

  defp entry_to_elixir({"transactions" = key, transactions}) do
    {key, Transactions.to_elixir(transactions)}
  end

  # Arbitrum fields
  defp entry_to_elixir({"l1BlockNumber", _}) do
    {:ignore, :ignore}
  end
end
