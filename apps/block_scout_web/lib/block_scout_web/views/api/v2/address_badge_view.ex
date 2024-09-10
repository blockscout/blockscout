defmodule BlockScoutWeb.API.V2.AddressBadgeView do
  use BlockScoutWeb, :view

  def render("badge.json", %{badge: badge, status: status}) do
    prepare_badge(badge, status)
  end

  def render("badge.json", %{badge: badge}) do
    prepare_badge(badge)
  end

  def render("badge_to_address.json", %{badge_to_address_list: badge_to_address_list, status: status}) do
    prepare_badge_to_address(badge_to_address_list, status)
  end

  def render("badge_to_address.json", %{badge_to_address_list: badge_to_address_list}) do
    prepare_badge_to_address(badge_to_address_list)
  end

  defp prepare_badge(badge) do
    %{
      id: badge.id,
      content: badge.content
    }
  end

  defp prepare_badge(badge, status) do
    %{
      id: badge.id,
      content: badge.content,
      status: status
    }
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
        badge_id: badge_to_address.badge_id,
        address_hash: "0x" <> Base.encode16(badge_to_address.address_hash.bytes)
      }
    end)
  end
end
