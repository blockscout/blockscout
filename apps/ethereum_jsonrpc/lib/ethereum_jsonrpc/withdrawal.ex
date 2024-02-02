defmodule EthereumJSONRPC.Withdrawal do
  @moduledoc """
  Withdrawal format included in the return of
  `eth_getBlockByHash` and `eth_getBlockByNumber`
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @type elixir :: %{
          String.t() => EthereumJSONRPC.address() | EthereumJSONRPC.hash() | String.t() | non_neg_integer() | nil
        }

  @typedoc """
  * `"index"` - the withdrawal number `t:EthereumJSONRPC.quantity/0`.
  * `"validatorIndex"` - the validator number initiated the withdrawal `t:EthereumJSONRPC.quantity/0`.
  * `"address"` - `t:EthereumJSONRPC.address/0` of the receiver.
  * `"amount"` - `t:EthereumJSONRPC.quantity/0` of wei transferred.
  """
  @type t :: %{
          String.t() =>
            EthereumJSONRPC.address() | EthereumJSONRPC.hash() | EthereumJSONRPC.quantity() | String.t() | nil
        }

  @type params :: %{
          index: non_neg_integer(),
          validator_index: non_neg_integer(),
          address_hash: EthereumJSONRPC.address(),
          block_hash: EthereumJSONRPC.hash(),
          block_number: non_neg_integer(),
          amount: non_neg_integer()
        }

  @doc """
  Converts `t:elixir/0` to `t:params/0`.

      iex> EthereumJSONRPC.Withdrawal.elixir_to_params(
      ...>  %{
      ...>    "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>    "amount" => 4040000000000,
      ...>    "index" => 3867,
      ...>    "validatorIndex" => 1721,
      ...>    "blockHash" => "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
      ...>    "blockNumber" => 3
      ...>  }
      ...> )
      %{
        address_hash: "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
        amount: 4040000000000,
        block_hash: "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
        block_number: 3,
        index: 3867,
        validator_index: 1721
      }
  """
  @spec elixir_to_params(elixir) :: params
  def elixir_to_params(%{
        "index" => index,
        "validatorIndex" => validator_index,
        "address" => address_hash,
        "amount" => amount,
        "blockHash" => block_hash,
        "blockNumber" => block_number
      }) do
    %{
      index: index,
      validator_index: validator_index,
      address_hash: address_hash,
      block_hash: block_hash,
      block_number: block_number,
      amount: amount
    }
  end

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.

      iex> EthereumJSONRPC.Withdrawal.to_elixir(
      ...>  %{
      ...>    "index" => "0xf1b",
      ...>    "validatorIndex" => "0x6b9",
      ...>    "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
      ...>    "amount" => "0x3aca2c3d000"
      ...>  }, "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a", 1
      ...> )
      %{
        "address" => "0x388ea662ef2c223ec0b047d41bf3c0f362142ad5",
        "amount" => 4040000000000,
        "blockHash" => "0x7f035c5f3c0678250853a1fde6027def7cac1812667bd0d5ab7ccb94eb8b6f3a",
        "index" => 3867,
        "validatorIndex" => 1721,
        "blockNumber" => 1
      }
  """
  @spec to_elixir(%{String.t() => String.t()}, String.t(), non_neg_integer()) :: elixir
  def to_elixir(withdrawal, block_hash, block_number) when is_map(withdrawal) do
    Enum.into(withdrawal, %{"blockHash" => block_hash, "blockNumber" => block_number}, &entry_to_elixir/1)
  end

  defp entry_to_elixir({key, value}) when key in ~w(index validatorIndex amount), do: {key, quantity_to_integer(value)}
  defp entry_to_elixir({key, value}) when key in ~w(address), do: {key, value}
end
