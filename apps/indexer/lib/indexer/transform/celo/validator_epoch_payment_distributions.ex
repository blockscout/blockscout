defmodule Indexer.Transform.Celo.ValidatorEpochPaymentDistributions do
  @moduledoc """
  Extracts data from `ValidatorEpochPaymentDistributed` event logs of the
  `Validators` Celo core contract.
  """
  alias ABI.FunctionSelector

  alias Explorer.Chain.Cache.CeloCoreContracts
  alias Explorer.Chain.{Hash, Log}

  require Logger

  @event_signature "0x6f5937add2ec38a0fa4959bccd86e3fcc2aafb706cd3e6c0565f87a7b36b9975"

  @event_abi [
    %{
      "name" => "ValidatorEpochPaymentDistributed",
      "type" => "event",
      "anonymous" => false,
      "inputs" => [
        %{
          "indexed" => true,
          "name" => "validator",
          "type" => "address"
        },
        %{
          "indexed" => false,
          "name" => "validatorPayment",
          "type" => "uint256"
        },
        %{
          "indexed" => true,
          "name" => "group",
          "type" => "address"
        },
        %{
          "indexed" => false,
          "name" => "groupPayment",
          "type" => "uint256"
        }
      ]
    }
  ]

  def signature, do: @event_signature

  def parse(logs) do
    logs
    |> Enum.filter(fn log ->
      {:ok, validators_contract_address} = CeloCoreContracts.get_address(:validators, log.block_number)

      Hash.to_string(log.address_hash) == validators_contract_address and
        Hash.to_string(log.first_topic) == @event_signature
    end)
    |> Enum.map(fn log ->
      {:ok, %FunctionSelector{},
       [
         {"validator", "address", true, validator_address_bytes},
         {"validatorPayment", "uint256", false, validator_payment},
         {"group", "address", true, group_address_bytes},
         {"groupPayment", "uint256", false, group_payment}
       ]} = Log.find_and_decode(@event_abi, log, log.block_hash)

      {:ok, validator_address} = Hash.Address.cast(validator_address_bytes)
      {:ok, group_address} = Hash.Address.cast(group_address_bytes)

      %{
        validator_address: validator_address,
        validator_payment: validator_payment,
        group_address: group_address,
        group_payment: group_payment
      }
    end)
  end
end
