defmodule Explorer.Celo.ContractEvents.Registry.RegistryUpdatedEvent do
  @moduledoc """
  Struct modelling the RegistryUpdated event from the Registry Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "RegistryUpdated",
    topic: "0x4166d073a7a5e704ce0db7113320f88da2457f872d46dc020c805c562c1582a0"

  event_param(:identifier, :string, :unindexed)
  event_param(:identifier_hash, {:bytes, 32}, :indexed)
  event_param(:addr, :address, :indexed)

  def raw_registry_updated_logs do
    from(log in "logs",
      select: [
        :first_topic,
        :second_topic,
        :third_topic,
        :data,
        :address_hash,
        :block_number,
        :block_hash,
        :transaction_hash,
        :index,
        :type
      ],
      where: log.first_topic == ^@topic and fragment("l0.address_hash = '\\x000000000000000000000000000000000000ce10'")
    )
  end
end
