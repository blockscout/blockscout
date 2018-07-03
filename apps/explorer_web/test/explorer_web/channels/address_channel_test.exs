defmodule ExplorerWeb.AddressChannelTest do
  use ExplorerWeb.ChannelCase

  describe "addresses channel tests" do
    test "subscribed user can receive transaction event" do
      channel = "addresses"
      @endpoint.subscribe(channel)

      ExplorerWeb.Endpoint.broadcast(channel, "transaction", %{body: "test"})

      receive do
        %Phoenix.Socket.Broadcast{event: "transaction", topic: ^channel, payload: %{body: body}} ->
          assert body == "test"
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end

    test "subscribed user can receive overview event" do
      channel = "addresses"
      @endpoint.subscribe(channel)

      ExplorerWeb.Endpoint.broadcast(channel, "overview", %{body: "test"})

      receive do
        %Phoenix.Socket.Broadcast{event: "overview", topic: ^channel, payload: %{body: body}} ->
          assert body == "test"
      after
        5_000 ->
          assert false, "Expected message received nothing."
      end
    end
  end
end
