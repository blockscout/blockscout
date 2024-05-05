defmodule Indexer.Transform.Celo.Epoch.ValidatorEpochPaymentDistributions do
  @moduledoc """
  Extracts data from `ValidatorEpochPaymentDistributed` event logs of the
  `Validators` Celo core contract.
  """
  alias ABI.{Event, FunctionSelector}

  alias Explorer.Chain.Cache.CeloCoreContracts

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

  defp find_and_decode_log(abi, log) do
    [topic0, topic1, topic2, topic3] =
      [
        log.first_topic,
        log.second_topic,
        log.third_topic,
        log.fourth_topic
      ]
      |> Enum.map(
        &(&1 &&
            &1
            |> String.trim_leading("0x")
            |> Base.decode16!(case: :mixed))
      )

    decoded_data =
      log.data
      |> String.trim_leading("0x")
      |> Base.decode16!(case: :mixed)

    with {
           %FunctionSelector{
             method_id: <<first_four_bytes::binary-size(4), _::binary>>
           } = selector,
           mapping
         } <-
           abi
           |> ABI.parse_specification(include_events?: true)
           |> Event.find_and_decode(
             topic0,
             topic1,
             topic2,
             topic3,
             decoded_data
           ),
         selector <- %{selector | method_id: first_four_bytes} do
      {:ok, selector, mapping}
    end
  rescue
    e ->
      Logger.warn(fn ->
        [
          "Could not decode input data for log #{inspect(log)}",
          Exception.format(:error, e, __STACKTRACE__)
        ]
      end)

      {:error, :could_not_decode}
  end

  def parse(logs) do
    validators_contract_address = CeloCoreContracts.get_address(:validators)

    logs
    |> Enum.filter(
      &(&1.address_hash == validators_contract_address and
          &1.first_topic == @event_signature)
    )
    |> Enum.map(fn log ->
      {:ok, %FunctionSelector{},
       [
         {"validator", "address", true, validator_address},
         {"validatorPayment", "uint256", false, validator_payment},
         {"group", "address", true, group_address},
         {"groupPayment", "uint256", false, group_payment}
       ]} =
        @event_abi
        |> find_and_decode_log(log)

      %{
        validator_address: "0x" <> Base.encode16(validator_address, case: :lower),
        validator_payment: validator_payment,
        group_address: "0x" <> Base.encode16(group_address, case: :lower),
        group_payment: group_payment
      }
    end)
  end
end
