defmodule Explorer.JSONRPC.Blocks do
  @moduledoc """
  Blocks format as returned by [`eth_getBlockByHash`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbyhash)
  and [`eth_getBlockByNumber`](https://github.com/ethereum/wiki/wiki/JSON-RPC#eth_getblockbynumber) from batch requests.
  """

  alias Explorer.JSONRPC.{Block, Transactions}

  # Types

  @type elixir :: [Block.elixir()]
  @type t :: [Block.t()]

  # Functions

  @spec elixir_to_params(elixir) :: [map]
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Block.elixir_to_params/1)
  end

  @spec elixir_to_transactions(t) :: Transactions.elixir()
  def elixir_to_transactions(elixir) when is_list(elixir) do
    Enum.flat_map(elixir, &Block.elixir_to_transactions/1)
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0` and the timestamps to `t:DateTime.t/0`

      iex> Explorer.JSONRPC.Blocks.to_elixir(
      ...>   [
      ...>     %{
      ...>       "author" => "0x0000000000000000000000000000000000000000",
      ...>       "difficulty" => "0x20000",
      ...>       "extraData" => "0x",
      ...>       "gasLimit" => "0x663be0",
      ...>       "gasUsed" => "0x0",
      ...>       "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
      ...>       "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>       "miner" => "0x0000000000000000000000000000000000000000",
      ...>       "number" => "0x0",
      ...>       "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
      ...>       "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>       "sealFields" => ["0x80",
      ...>        "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"],
      ...>       "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
      ...>       "signature" => "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
      ...>       "size" => "0x215",
      ...>       "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
      ...>       "step" => "0",
      ...>       "timestamp" => "0x0",
      ...>       "totalDifficulty" => "0x20000",
      ...>       "transactions" => [],
      ...>       "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
      ...>       "uncles" => []
      ...>     }
      ...>   ]
      ...> )
      [
        %{
          "author" => "0x0000000000000000000000000000000000000000",
          "difficulty" => 131072,
          "extraData" => "0x",
          "gasLimit" => 6700000,
          "gasUsed" => 0,
          "hash" => "0x5b28c1bfd3a15230c9a46b399cd0f9a6920d432e85381cc6a140b06e8410112f",
          "logsBloom" => "0x00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          "miner" => "0x0000000000000000000000000000000000000000",
          "number" => 0,
          "parentHash" => "0x0000000000000000000000000000000000000000000000000000000000000000",
          "receiptsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
          "sealFields" => ["0x80",
           "0xb8410000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"],
          "sha3Uncles" => "0x1dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d49347",
          "signature" => "0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000",
          "size" => 533,
          "stateRoot" => "0xfad4af258fd11939fae0c6c6eec9d340b1caac0b0196fd9a1bc3f489c5bf00b3",
          "step" => "0",
          "timestamp" => Timex.parse!("1970-01-01T00:00:00Z", "{ISO:Extended:Z}"),
          "totalDifficulty" => 131072,
          "transactions" => [],
          "transactionsRoot" => "0x56e81f171bcc55a6ff8345e692c0f86e5b48e01b996cadc001622fb5e363b421",
          "uncles" => []
        }
      ]
  """
  @spec to_elixir(t) :: elixir
  def to_elixir(blocks) when is_list(blocks) do
    Enum.map(blocks, &Block.to_elixir/1)
  end
end
