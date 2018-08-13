defmodule ExplorerWeb.AddressTransactionTest do
  use ExplorerWeb.ChannelCase

  describe "transactions channel tests" do
    test "subscribed user can receive block confirmations event" do
      channel = "transactions"
      @endpoint.subscribe(channel)

      block = insert(:block, number: 1)

      transaction =
        :transaction
        |> insert()
        |> with_block(block)

      ExplorerWeb.Endpoint.broadcast(channel, "confirmations", %{max_block_number: 3, transaction: transaction})

      receive do
        %Phoenix.Socket.Broadcast{
          event: "confirmations",
          topic: ^channel,
          payload: %{max_block_number: 3, transaction: ^transaction}
        } ->
          assert true
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end
  end
end
