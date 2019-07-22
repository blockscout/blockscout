defmodule BlockScoutWeb.AddressLogsView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Transaction

  def decode_transaction(transaction) do
    Transaction.decoded_input_data(transaction)
  end
end
