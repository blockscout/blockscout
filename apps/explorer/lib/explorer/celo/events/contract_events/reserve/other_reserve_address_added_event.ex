defmodule Explorer.Celo.ContractEvents.Reserve.OtherReserveAddressAddedEvent do
  @moduledoc """
  Struct modelling the OtherReserveAddressAdded event from the Reserve Celo core contract.
  """

  use Explorer.Celo.ContractEvents.Base,
    name: "OtherReserveAddressAdded",
    topic: "0xd78793225285ecf9cf5f0f84b1cdc335c2cb4d6810ff0b9fd156ad6026c89cea"

  event_param(:other_reserve_address, :address, :indexed)
end
