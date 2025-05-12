defmodule BlockScoutWeb.Account.API.V2.UserView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.Account.API.V2.AccountView
  alias BlockScoutWeb.API.V2.Helper
  alias Ecto.Changeset
  alias Explorer.Account.WatchlistAddress
  alias Explorer.Chain
  alias Explorer.Chain.Address

  def render("message.json", assigns) do
    AccountView.render("message.json", assigns)
  end

  def render("user_info.json", %{identity: identity}) do
    %{
      "name" => identity.name,
      "email" => identity.email,
      "avatar" => identity.avatar,
      "nickname" => identity.nickname,
      "address_hash" => identity.address_hash
    }
  end

  def render("watchlist_addresses.json", %{
        watchlist_addresses: watchlist_addresses,
        exchange_rate: exchange_rate,
        next_page_params: next_page_params
      }) do
    prepared_watchlist_addresses = prepare_watchlist_addresses(watchlist_addresses, exchange_rate)

    %{
      "items" => prepared_watchlist_addresses,
      "next_page_params" => next_page_params
    }
  end

  def render("watchlist_addresses.json", %{watchlist_addresses: watchlist_addresses, exchange_rate: exchange_rate}) do
    prepare_watchlist_addresses(watchlist_addresses, exchange_rate)
  end

  def render("watchlist_address.json", %{watchlist_address: watchlist_address, exchange_rate: exchange_rate}) do
    address = Address.get_by_hash(watchlist_address.address_hash)
    prepare_watchlist_address(watchlist_address, address, exchange_rate)
  end

  def render("address_tags.json", %{address_tags: address_tags, next_page_params: next_page_params}) do
    %{"items" => Enum.map(address_tags, &prepare_address_tag/1), "next_page_params" => next_page_params}
  end

  def render("address_tags.json", %{address_tags: address_tags}) do
    Enum.map(address_tags, &prepare_address_tag/1)
  end

  def render("address_tag.json", %{address_tag: address_tag}) do
    prepare_address_tag(address_tag)
  end

  def render("transaction_tags.json", %{transaction_tags: transaction_tags, next_page_params: next_page_params}) do
    %{"items" => Enum.map(transaction_tags, &prepare_transaction_tag/1), "next_page_params" => next_page_params}
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

  def render("public_tags_requests.json", %{public_tags_requests: public_tags_requests}) do
    Enum.map(public_tags_requests, &prepare_public_tags_request/1)
  end

  def render("public_tags_request.json", %{public_tags_request: public_tags_request}) do
    prepare_public_tags_request(public_tags_request)
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

  @spec prepare_watchlist_address(WatchlistAddress.t(), Chain.Address.t(), map()) :: map
  defp prepare_watchlist_address(watchlist, address, exchange_rate) do
    %{
      "id" => watchlist.id,
      "address" => Helper.address_with_info(nil, address, watchlist.address_hash, false),
      "address_hash" => watchlist.address_hash,
      "name" => watchlist.name,
      "address_balance" => if(address && address.fetched_coin_balance, do: address.fetched_coin_balance.value),
      "exchange_rate" => exchange_rate.fiat_value,
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
        },
        # "ERC-1155" => %{
        #   "incoming" => watchlist.watch_erc_1155_input,
        #   "outcoming" => watchlist.watch_erc_1155_output
        # },
        "ERC-404" => %{
          "incoming" => watchlist.watch_erc_404_input,
          "outcoming" => watchlist.watch_erc_404_output
        }
      },
      "notification_methods" => %{
        "email" => watchlist.notify_email
      },
      "tokens_fiat_value" => watchlist.tokens_fiat_value,
      "tokens_count" => watchlist.tokens_count,
      "tokens_overflow" => watchlist.tokens_overflow
    }
  end

  @spec prepare_watchlist_addresses([WatchlistAddress.t()], map()) :: [map()]
  defp prepare_watchlist_addresses(watchlist_addresses, exchange_rate) do
    address_hashes =
      watchlist_addresses
      |> Enum.map(& &1.address_hash)

    addresses = Address.get_addresses_by_hashes(address_hashes)

    watchlist_addresses
    |> Enum.zip(addresses)
    |> Enum.map(fn {watchlist, address} ->
      prepare_watchlist_address(watchlist, address, exchange_rate)
    end)
  end

  defp prepare_custom_abi(custom_abi) do
    address = Address.get_by_hash(custom_abi.address_hash)

    %{
      "id" => custom_abi.id,
      "contract_address_hash" => custom_abi.address_hash,
      "contract_address" => Helper.address_with_info(nil, address, custom_abi.address_hash, false),
      "name" => custom_abi.name,
      "abi" => custom_abi.abi
    }
  end

  defp prepare_api_key(api_key) do
    %{"api_key" => api_key.value, "name" => api_key.name}
  end

  defp prepare_address_tag(address_tag) do
    address = Address.get_by_hash(address_tag.address_hash)

    %{
      "id" => address_tag.id,
      "address_hash" => address_tag.address_hash,
      "address" => Helper.address_with_info(nil, address, address_tag.address_hash, false),
      "name" => address_tag.name
    }
  end

  defp prepare_transaction_tag(nil), do: nil

  defp prepare_transaction_tag(transaction_tag) do
    %{
      "id" => transaction_tag.id,
      "transaction_hash" => transaction_tag.transaction_hash,
      "name" => transaction_tag.name
    }
  end

  defp prepare_public_tags_request(public_tags_request) do
    addresses = Address.get_addresses_by_hashes(public_tags_request.addresses)

    addresses_with_info =
      Enum.map(addresses, fn address ->
        Helper.address_with_info(nil, address, address.hash, false)
      end)

    %{
      "id" => public_tags_request.id,
      "full_name" => public_tags_request.full_name,
      "email" => public_tags_request.email,
      "company" => public_tags_request.company,
      "website" => public_tags_request.website,
      "tags" => public_tags_request.tags,
      "addresses" => public_tags_request.addresses,
      "addresses_with_info" => addresses_with_info,
      "additional_comment" => public_tags_request.additional_comment,
      "is_owner" => public_tags_request.is_owner,
      "submission_date" => public_tags_request.inserted_at
    }
  end
end
