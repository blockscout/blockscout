defmodule BlockScoutWeb.ChecksumAddress do
  @moduledoc """
  Adds checksummed version of address hashes.
  """

  import Plug.Conn

  alias BlockScoutWeb.Controller, as: BlockScoutWebController
  alias Explorer.Chain
  alias Explorer.Chain.Address
  alias Phoenix.Controller
  alias Plug.Conn

  def init(opts), do: opts

  def call(%Conn{params: %{"id" => id}} = conn, _opts) do
    check_checksum(conn, id, "id")
  end

  def call(%Conn{params: %{"address_id" => id}} = conn, _opts) do
    check_checksum(conn, id, "address_id")
  end

  def call(conn, _), do: conn

  defp check_checksum(conn, id, param_name) do
    if Application.get_env(:block_scout_web, :checksum_address_hashes) do
      case Chain.string_to_address_hash(id) do
        {:ok, address_hash} ->
          checksummed_hash = Address.checksum(address_hash)

          if checksummed_hash != id do
            conn = %{conn | params: Map.merge(conn.params, %{param_name => checksummed_hash})}

            path_with_checksummed_address = String.replace(conn.request_path, id, checksummed_hash)

            new_path =
              if conn.query_string != "" do
                path_with_checksummed_address <> "?" <> conn.query_string
              else
                path_with_checksummed_address
              end

            conn
            |> Controller.redirect(to: new_path |> BlockScoutWebController.full_path())
            |> halt
          else
            conn
          end

        _ ->
          conn
      end
    else
      conn
    end
  end
end
