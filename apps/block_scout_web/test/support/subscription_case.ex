defmodule BlockScoutWeb.SubscriptionCase do
  @moduledoc """
  This module defines the test case to be used by GraphQL subscription tests.
  """

  use ExUnit.CaseTemplate

  import Phoenix.ChannelTest, only: [connect: 2]

  @endpoint BlockScoutWeb.Endpoint

  using do
    quote do
      # Import conveniences for testing with channels
      use BlockScoutWeb.ChannelCase
      use Absinthe.Phoenix.SubscriptionTest, schema: BlockScoutWeb.Schema
    end
  end

  @dialyzer {:nowarn_function, __ex_unit_setup_0: 1}
  setup do
    {:ok, socket} = connect(BlockScoutWeb.UserSocket, %{})
    {:ok, socket} = Absinthe.Phoenix.SubscriptionTest.join_absinthe(socket)

    {:ok, socket: socket}
  end
end
