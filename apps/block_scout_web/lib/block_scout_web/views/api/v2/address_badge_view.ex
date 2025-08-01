defmodule BlockScoutWeb.API.V2.AddressBadgeView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.Address

  def render("badge_to_address.json", %{badge_to_address_list: badge_to_address_list, status: status}) do
    prepare_badge_to_address(badge_to_address_list, status)
  end

  def render("badge_to_address.json", %{badge_to_address_list: badge_to_address_list}) do
    prepare_badge_to_address(badge_to_address_list)
  end

  defp prepare_badge_to_address(badge_to_address_list) do
    %{
      badge_to_address_list: format_badge_to_address_list(badge_to_address_list)
    }
  end

  defp prepare_badge_to_address(badge_to_address_list, status) do
    %{
      badge_to_address_list: format_badge_to_address_list(badge_to_address_list),
      status: status
    }
  end

  defp format_badge_to_address_list(badge_to_address_list) do
    badge_to_address_list
    |> Enum.map(fn badge_to_address ->
      %{
        address_hash: Address.checksum(badge_to_address.address_hash)
      }
    end)
  end
end
