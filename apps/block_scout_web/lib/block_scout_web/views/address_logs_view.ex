defmodule BlockScoutWeb.AddressLogsView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Address, Log}

  def decode(log, transaction) do
    Log.decode(log, transaction)
  end
end
