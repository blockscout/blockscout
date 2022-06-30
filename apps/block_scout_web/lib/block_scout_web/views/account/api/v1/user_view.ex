defmodule BlockScoutWeb.Account.Api.V1.UserView do
  alias BlockScoutWeb.Account.Api.V1.AccountView
  alias Ecto.Changeset

  def render("error.json", assigns) do
    AccountView.render("error.json", assigns)
  end

  def render("user_info.json", %{identity: identity}) do
    %{"name" => identity.name, "email" => identity.email, "avatar" => identity.avatar, "nickname" => identity.nickname}
  end

  def render("watchlist_addresses.json", %{watchlist_addresses: watchlist_addresses, exchange_rate: exchange_rate}) do
    Enum.map(watchlist_addresses, &prepare_watchlist_address(&1, exchange_rate))
  end

  def render("watchlist_address.json", %{watchlist_address: watchlist_address, exchange_rate: exchange_rate}) do
    prepare_watchlist_address(watchlist_address, exchange_rate)
  end

  def render("address_tags.json", %{address_tags: address_tags}) do
    Enum.map(address_tags, &prepare_address_tag/1)
  end

  def render("address_tag.json", %{address_tag: address_tag}) do
    prepare_address_tag(address_tag)
  end

  def render("transaction_tags.json", %{transaction_tags: transaction_tags}) do
    Enum.map(transaction_tags, &prepare_transaction_tag/1)
  end

  def render("transaction_tag.json", %{transaction_tag: transaction_tag}) do
    prepare_transaction_tag(transaction_tag)
  end

  def render("api_keys.json", %{api_keys: api_keys}) do
    Enum.map(api_keys, &prepare_api_key/1)
  end

  def render("api_key.json", %{api_key: api_key}) do
    prepare_api_key(api_key)
  end

  def render("custom_abis.json", %{custom_abis: custom_abis}) do
    Enum.map(custom_abis, &prepare_custom_abi/1)
  end

  def render("custom_abi.json", %{custom_abi: custom_abi}) do
    prepare_custom_abi(custom_abi)
  end

  def render("changeset_errors.json", %{changeset: changeset}) do
    %{
      "errors" =>
        Changeset.traverse_errors(changeset, fn {msg, opts} ->
          Regex.replace(~r"%{(\w+)}", msg, fn _, key ->
            opts |> Keyword.get(String.to_existing_atom(key), key) |> to_string()
          end)
        end)
    }
  end

  def prepare_watchlist_address(watchlist, exchange_rate) do
    %{
      "id" => watchlist.id,
      "address_hash" => watchlist.address_hash,
      "name" => watchlist.name,
      "address_balance" => if(watchlist.address.fetched_coin_balance, do: watchlist.address.fetched_coin_balance.value),
      "exchange_rate" => exchange_rate.usd_value,
      "notification_settings" => %{
        "native" => %{
          "incoming" => watchlist.watch_coin_input,
          "outcoming" => watchlist.watch_coin_output
        },
        "ERC-20" => %{
          "incoming" => watchlist.watch_erc_20_input,
          "outcoming" => watchlist.watch_erc_20_output
        },
        "ERC-721" => %{
          "incoming" => watchlist.watch_erc_721_input,
          "outcoming" => watchlist.watch_erc_721_output
        }
        # ,
        # "ERC-1155" => %{
        #   "incoming" => watchlist.watch_erc_1155_input,
        #   "outcoming" => watchlist.watch_erc_1155_output
        # }
      },
      "notification_methods" => %{
        "email" => watchlist.notify_email
      }
    }
  end

  def prepare_custom_abi(custom_abi) do
    %{
      "id" => custom_abi.id,
      "contract_address_hash" => custom_abi.address_hash,
      "name" => custom_abi.name,
      "abi" => custom_abi.abi
    }
  end

  def prepare_api_key(api_key) do
    %{"api_key" => api_key.value, "name" => api_key.name}
  end

  def prepare_address_tag(address_tag) do
    %{"id" => address_tag.id, "address_hash" => address_tag.address_hash, "name" => address_tag.name}
  end

  def prepare_transaction_tag(nil), do: nil

  def prepare_transaction_tag(transaction_tag) do
    %{"id" => transaction_tag.id, "transaction_hash" => transaction_tag.tx_hash, "name" => transaction_tag.name}
  end
end
