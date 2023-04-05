defmodule BlockScoutWeb.Tokens.TokenController do
  use BlockScoutWeb, :controller

  require Logger

  alias BlockScoutWeb.AccessHelper
  alias Explorer.Chain

  def show(conn, %{"id" => address_hash_string}) do
    redirect(conn, to: AccessHelper.get_path(conn, :token_transfer_path, :index, address_hash_string))
  end

  def token_counters(conn, %{"id" => address_hash_string}) do
    case Chain.string_to_address_hash(address_hash_string) do
      {:ok, address_hash} ->
        {transfer_count, token_holder_count} = Chain.fetch_token_counters(address_hash, 30_000)

        json(conn, %{transfer_count: transfer_count, token_holder_count: token_holder_count})

      _ ->
        not_found(conn)
    end
  end
end
