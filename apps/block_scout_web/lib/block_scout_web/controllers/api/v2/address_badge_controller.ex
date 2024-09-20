defmodule BlockScoutWeb.API.V2.AddressBadgeController do
  require Logger
  use BlockScoutWeb, :controller

  alias Explorer.Chain
  alias Explorer.Chain.Address.ScamBadgeToAddress
  alias Plug.Conn

  @api_true [api?: true]

  action_fallback(BlockScoutWeb.API.V2.FallbackController)

  def assign_badge_to_address(
        conn,
        %{
          "address_hashes" => address_hashes
        } = params
      )
      when is_list(address_hashes) do
    with :ok <- check_sensitive_endpoint_api_key(params["api_key"]),
         valid_address_hashes = filter_address_hashes(address_hashes),
         {_num_of_inserted, badge_to_address_list} <- ScamBadgeToAddress.add(valid_address_hashes) do
      conn
      |> put_status(200)
      |> render(:badge_to_address, %{
        badge_to_address_list: badge_to_address_list,
        status: if(Enum.empty?(badge_to_address_list), do: "update skipped", else: "added")
      })
    end
  end

  def assign_badge_to_address(_, _), do: {:error, :not_found}

  def unassign_badge_from_address(
        conn,
        %{
          "address_hashes" => address_hashes
        } = params
      )
      when is_list(address_hashes) do
    with :ok <- check_sensitive_endpoint_api_key(params["api_key"]),
         valid_address_hashes = filter_address_hashes(address_hashes),
         {_num_of_deleted, badge_to_address_list} <- ScamBadgeToAddress.delete(valid_address_hashes) do
      conn
      |> put_status(200)
      |> render(:badge_to_address, %{
        badge_to_address_list: badge_to_address_list,
        status: if(Enum.empty?(badge_to_address_list), do: "update skipped", else: "removed")
      })
    end
  end

  def unassign_badge_from_address(_, _), do: {:error, :not_found}

  def show_badge_addresses(conn, _) do
    with {:ok, body, _conn} <- Conn.read_body(conn, []),
         {:ok, %{"api_key" => provided_api_key}} <- Jason.decode(body),
         :ok <- check_sensitive_endpoint_api_key(provided_api_key) do
      badge_to_address_list = ScamBadgeToAddress.get(@api_true)

      conn
      |> put_status(200)
      |> render(:badge_to_address, %{
        badge_to_address_list: badge_to_address_list
      })
    else
      _ ->
        {:error, :not_found}
    end
  end

  defp check_sensitive_endpoint_api_key(provided_api_key) do
    with {:sensitive_endpoints_api_key, api_key} when not is_nil(api_key) <-
           {:sensitive_endpoints_api_key, Application.get_env(:block_scout_web, :sensitive_endpoints_api_key)},
         {:api_key, ^api_key} <- {:api_key, provided_api_key} do
      :ok
    end
  end

  defp filter_address_hashes(address_hashes) do
    address_hashes
    |> Enum.uniq()
    |> Enum.filter(fn potential_address_hash ->
      case Chain.string_to_address_hash(potential_address_hash) do
        {:ok, _address_hash} -> true
        _ -> false
      end
    end)
  end
end
