defmodule EthereumJSONRPC.Nethermind.Trace.Action do
  @moduledoc """
  The action that was performed in a `t:EthereumJSONRPC.Nethermind.Trace.t/0`
  """

  import EthereumJSONRPC, only: [quantity_to_integer: 1]

  @doc """
  Decodes the stringly typed numerical fields to `t:non_neg_integer/0`.

      iex> EthereumJSONRPC.Nethermind.Trace.Action.to_elixir(
      ...>   %{
      ...>     "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
      ...>     "gas" => "0x462534",
      ...>     "init" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
      ...>     "value" => "0x0"
      ...>   }
      ...> )
      %{
        "from" => "0xe8ddc5c7a2d2f0d7a9798459c0104fdf5e987aca",
        "gas" => 4597044,
        "init" => "0x6060604052341561000f57600080fd5b336000806101000a81548173ffffffffffffffffffffffffffffffffffffffff021916908373ffffffffffffffffffffffffffffffffffffffff1602179055506102db8061005e6000396000f300606060405260043610610062576000357c0100000000000000000000000000000000000000000000000000000000900463ffffffff1680630900f01014610067578063445df0ac146100a05780638da5cb5b146100c9578063fdacd5761461011e575b600080fd5b341561007257600080fd5b61009e600480803573ffffffffffffffffffffffffffffffffffffffff16906020019091905050610141565b005b34156100ab57600080fd5b6100b3610224565b6040518082815260200191505060405180910390f35b34156100d457600080fd5b6100dc61022a565b604051808273ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff16815260200191505060405180910390f35b341561012957600080fd5b61013f600480803590602001909190505061024f565b005b60008060009054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff161415610220578190508073ffffffffffffffffffffffffffffffffffffffff1663fdacd5766001546040518263ffffffff167c010000000000000000000000000000000000000000000000000000000002815260040180828152602001915050600060405180830381600087803b151561020b57600080fd5b6102c65a03f1151561021c57600080fd5b5050505b5050565b60015481565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1681565b6000809054906101000a900473ffffffffffffffffffffffffffffffffffffffff1673ffffffffffffffffffffffffffffffffffffffff163373ffffffffffffffffffffffffffffffffffffffff1614156102ac57806001819055505b505600a165627a7a72305820a9c628775efbfbc17477a472413c01ee9b33881f550c59d21bee9928835c854b0029",
        "value" => 0
      }

  For a suicide, the `"balance"` is converted to a `t:non_neg_integer/0` while the `"address"` and `"refundAddress"`
  `t:EthereumJSONRPC.hash/0` pass through.

      iex> EthereumJSONRPC.Nethermind.Trace.Action.to_elixir(
      ...>   %{
      ...>    "address" => "0xa7542d78b9a0be6147536887e0065f16182d294b",
      ...>    "balance" => "0x0",
      ...>    "refundAddress" => "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5"
      ...>   }
      ...> )
      %{
        "address" => "0xa7542d78b9a0be6147536887e0065f16182d294b",
        "balance" => 0,
        "refundAddress" => "0x59e2e9ecf133649b1a7efc731162ff09d29ca5a5"
      }

  """
  def to_elixir(action) when is_map(action) do
    Enum.into(action, %{}, &entry_to_elixir/1)
  end

  defp entry_to_elixir({key, value} = entry)
       when key in ~w(address callType from init input refundAddress to creationMethod) and is_binary(value),
       do: entry

  defp entry_to_elixir({key, quantity}) when key in ~w(balance gas value) do
    {key, quantity_to_integer(quantity)}
  end
end
