defmodule BlockScoutWeb.API.V2.Helper do
  @moduledoc """
    API V2 helper
  """

  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.Address
  import BlockScoutWeb.Account.AuthController, only: [current_user: 1]
  import BlockScoutWeb.Models.GetAddressTags, only: [get_address_tags: 2, get_tags_on_address: 1]

  def address_with_info(conn, address, address_hash) do
    %{
      personal_tags: private_tags,
      watchlist_names: watchlist_names
    } = get_address_tags(address_hash, current_user(conn))

    public_tags = get_tags_on_address(address_hash)

    Map.merge(address_with_info(address, address_hash), %{
      "private_tags" => private_tags,
      "watchlist_names" => watchlist_names,
      "public_tags" => public_tags
    })
  end

  def address_with_info(%Address{} = address, _address_hash) do
    %{
      "hash" => to_string(address),
      "is_contract" => is_smart_contract(address),
      "name" => address_name(address),
      "implementation_name" => implementation_name(address)
    }
  end

  def address_with_info(%NotLoaded{}, address_hash) do
    address_with_info(nil, address_hash)
  end

  def address_with_info(nil, address_hash) do
    %{"hash" => address_hash, "is_contract" => false, "name" => nil, "implementation_name" => nil}
  end

  def address_name(%Address{names: [_ | _] = address_names}) do
    case Enum.find(address_names, &(&1.primary == true)) do
      nil ->
        %Address.Name{name: name} = Enum.at(address_names, 0)
        name

      %Address.Name{name: name} ->
        name
    end
  end

  def address_name(_), do: nil

  def implementation_name(%Address{smart_contract: %{implementation_name: implementation_name}}),
    do: implementation_name

  def implementation_name(_), do: nil

  def is_smart_contract(%Address{contract_code: nil}), do: false
  def is_smart_contract(%Address{contract_code: _}), do: true
  def is_smart_contract(_), do: false
end
