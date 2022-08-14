defmodule BlockScoutWeb.Account.TagAddressView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressView, only: [trimmed_hash: 1]

  alias Explorer.Account.TagAddress
end
