defmodule BlockScoutWeb.AddressLogsView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Address, Log}

  def decode(log, transaction) do
    {result, _contracts_acc, _events_acc} = Log.decode(log, transaction, [], true)
    result
  end
end
