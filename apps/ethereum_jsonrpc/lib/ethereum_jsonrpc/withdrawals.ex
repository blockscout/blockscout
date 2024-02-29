defmodule EthereumJSONRPC.Withdrawals do
  @moduledoc """
  List of withdrawals format included in the return of
  `eth_getBlockByHash` and `eth_getBlockByNumber`
  """

  alias EthereumJSONRPC.Withdrawal

  @type elixir :: [Withdrawal.elixir()]
  @type params :: [Withdrawal.params()]
  @type t :: [Withdrawal.t()]

  @doc """
  Converts `t:elixir/0` to `t:params/0`.

      iex> EthereumJSONRPC.Withdrawals.elixir_to_params([
      ...>   %{
      ...>     "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>     "amount" => 4040000000000,
      ...>     "index" => 3867,
      ...>     "validatorIndex" => 1721,
      ...>     "blockHash" => "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
      ...>     "blockNumber" => 1
      ...>   }
      ...> ])
      [
        %{
          address_hash: "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
          amount: 4040000000000000000000,
          block_hash: "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
          index: 3867,
          validator_index: 1721,
          block_number: 1
        }
      ]
  """
  @spec elixir_to_params(elixir) :: params
  def elixir_to_params(elixir) when is_list(elixir) do
    Enum.map(elixir, &Withdrawal.elixir_to_params/1)
  end

  @doc """
  Decodes stringly typed fields in entries of `withdrawals`.

      iex> EthereumJSONRPC.Withdrawals.to_elixir([
      ...>   %{
      ...>     "index" => "0xf1b",
      ...>     "validatorIndex" => "0x6b9",
      ...>     "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>     "amount" => "0x3aca2c3d000"
      ...>   }], "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a", 3)
      [
        %{
          "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
          "amount" => 4040000000000,
          "blockHash" => "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
          "index" => 3867,
          "blockNumber" => 3,
          "validatorIndex" => 1721
        }
      ]
  """
  @spec to_elixir([%{String.t() => String.t()}], String.t(), non_neg_integer()) :: elixir
  def to_elixir(withdrawals, block_hash, block_number) when is_list(withdrawals) do
    Enum.map(withdrawals, &Withdrawal.to_elixir(&1, block_hash, block_number))
  end
end
