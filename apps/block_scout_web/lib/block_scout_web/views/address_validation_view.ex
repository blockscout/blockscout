defmodule BlockScoutWeb.AddressValidationView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView,
    only: [contract?: 1, smart_contract_verified?: 1, smart_contract_with_read_only_functions?: 1]
end
