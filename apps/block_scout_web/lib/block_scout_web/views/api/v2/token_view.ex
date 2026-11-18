# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.API.V2.TokenView do
  use BlockScoutWeb, :view
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  alias BlockScoutWeb.API.V2.Helper
  alias BlockScoutWeb.NFTHelper
  alias Ecto.Association.NotLoaded
  alias Explorer.Chain.{Address, BridgedToken, Hash, SmartContract, Token}
  alias Explorer.Chain.Address.CurrentTokenBalance
  alias Explorer.Chain.Token.Instance

  def render("token.json", %{token: nil = token, contract_address_hash: contract_address_hash}) do
    %{
      "address_hash" => Address.checksum(contract_address_hash),
      "symbol" => nil,
      "name" => nil,
      "decimals" => nil,
      "type" => nil,
      "holders_count" => nil,
      "exchange_rate" => nil,
      "volume_24h" => nil,
      "total_supply" => nil,
      "icon_url" => nil,
      "circulating_market_cap" => nil,
      "circulating_supply" => nil,
      "reputation" => nil,
      "ui_multiplier" => nil,
      "new_ui_multiplier" => nil,
      "ui_multiplier_effective_at" => nil
    }
    |> maybe_append_bridged_info(token)
  end

  def render("token.json", %{token: nil}) do
    nil
  end

  def render("token.json", %{token: %Token{} = token, burn_address_balances: burn_address_balances}) do
    "token.json"
    |> render(%{token: token})
    |> Map.merge(burned_supply_fields(token, burn_address_balances))
  end

  def render("token.json", %{token: token}) do
    %{
      "address_hash" => Address.checksum(token.contract_address_hash),
      "symbol" => token.symbol,
      "name" => token.name,
      "decimals" => token.decimals,
      "type" => token.type,
      "holders_count" => prepare_holders_count(token.holder_count),
      "exchange_rate" => exchange_rate(token),
      "volume_24h" => token.volume_24h,
      "total_supply" => token.total_supply,
      "icon_url" => token.icon_url,
      "circulating_market_cap" => token.circulating_market_cap,
      "circulating_supply" => token.circulating_supply,
      "reputation" => token.reputation,
      "ui_multiplier" => Token.effective_ui_multiplier(token),
      "new_ui_multiplier" => token.new_ui_multiplier,
      "ui_multiplier_effective_at" => token.ui_multiplier_effective_at
    }
    |> maybe_append_bridged_info(token)
    |> chain_type_fields(%{address: token.contract_address, field_prefix: nil})
  end

  def render("token_holders.json", %{
        token_balances: token_balances,
        next_page_params: next_page_params
      }) do
    %{
      "items" => Enum.map(token_balances, &prepare_token_holder(&1)),
      "next_page_params" => next_page_params
    }
  end

  def render("ui_multiplier_changes.json", %{
        ui_multiplier_changes: ui_multiplier_changes,
        next_page_params: next_page_params
      }) do
    %{
      "items" => Enum.map(ui_multiplier_changes, &prepare_ui_multiplier_change/1),
      "next_page_params" => next_page_params
    }
  end

  def render("token_instance.json", %{token_instance: token_instance, token: token}) do
    prepare_token_instance(token_instance, token)
  end

  def render("tokens.json", %{tokens: tokens, next_page_params: next_page_params}) do
    %{"items" => Enum.map(tokens, &render("token.json", %{token: &1})), "next_page_params" => next_page_params}
  end

  def render("tokens_batch.json", %{tokens: tokens}) do
    Enum.map(tokens, &render("token.json", %{token: &1}))
  end

  def render("token_instances.json", %{
        token_instances: token_instances,
        next_page_params: next_page_params,
        token: token
      }) do
    %{
      "items" =>
        Enum.map(token_instances, fn instance ->
          instance
          |> prepare_token_instance(token)
          |> Map.delete("token")
        end),
      "next_page_params" => next_page_params
    }
  end

  def render("bridged_tokens.json", %{tokens: tokens, next_page_params: next_page_params}) do
    %{"items" => Enum.map(tokens, &render("bridged_token.json", %{token: &1})), "next_page_params" => next_page_params}
  end

  def render(
        "bridged_token.json",
        %{token: {token, _bridged_token}, burn_address_balances: burn_address_balances} = assigns
      ) do
    "bridged_token.json"
    |> render(Map.delete(assigns, :burn_address_balances))
    |> Map.merge(burned_supply_fields(token, burn_address_balances))
  end

  def render("bridged_token.json", %{token: {token, bridged_token}}) do
    "token.json"
    |> render(%{token: token})
    |> Map.merge(%{
      foreign_address: Address.checksum(bridged_token.foreign_token_contract_address_hash),
      bridge_type: bridged_token.type,
      origin_chain_id: bridged_token.foreign_chain_id
    })
  end

  def exchange_rate(%{fiat_value: fiat_value}) when not is_nil(fiat_value), do: to_string(fiat_value)
  def exchange_rate(_), do: nil

  defp prepare_ui_multiplier_change(change) do
    %{
      "block_number" => change.block_number,
      "block_hash" => to_string(change.block_hash),
      "timestamp" => change.timestamp,
      "transaction_hash" => change.transaction_hash && to_string(change.transaction_hash),
      "log_index" => change.log_index,
      "old_multiplier" => change.old_multiplier,
      "new_multiplier" => change.new_multiplier,
      "effective_at" => change.effective_at
    }
  end

  defp prepare_token_holder(token_balance) do
    %{
      "address" => Helper.address_with_info(nil, token_balance.address, token_balance.address_hash, false),
      "value" => token_balance.value,
      "token_id" => token_balance.token_id,
      "is_burn_address" => token_balance.address_hash in SmartContract.burn_address_hashes()
    }
  end

  # Burn address balances, burned supply and on-chain circulating supply of the
  # token detail endpoint. `burn_address_balances` holds the current balance rows
  # of the burn addresses, see
  # `Explorer.Chain.Address.CurrentTokenBalance.burn_address_balances/2`.
  #
  # `burned_supply` needs the balances of all burn addresses, so it is `nil`
  # while one is not indexed yet. `calculated_circulating_supply` must also
  # describe one state: `total_supply` is read at `total_supply_updated_at_block`,
  # and every mint or burn moves the zero address balance to the block of its
  # transfer. A zero address balance newer than `total_supply` therefore means a
  # supply change that `total_supply` may not include yet, and the value is
  # `nil` until `total_supply` is refreshed. Transfers to the dead address do not
  # change `totalSupply()`, so the dead address balance block does not matter.
  #
  # Raw amounts are `uint256`, up to 78 digits, beyond the 28 significant digits
  # of the default `Decimal` context, so the arithmetic is done on integers and
  # the results are rendered as integer strings.
  @spec burned_supply_fields(Token.t(), %{Hash.Address.t() => CurrentTokenBalance.burn_address_balance()}) :: map()
  defp burned_supply_fields(token, burn_address_balances) do
    balances =
      if token.type in CurrentTokenBalance.fungible_token_types(),
        do: indexed_burn_address_balances(burn_address_balances),
        else: []

    burned_supply =
      if Enum.count(balances) == Enum.count(SmartContract.burn_address_hashes()),
        do: balances |> Enum.map(& &1.value) |> Enum.sum()

    %{
      "burn_address_balances" => if(balances != [], do: Enum.map(balances, &render_burn_address_balance/1)),
      "burned_supply" => burned_supply && Integer.to_string(burned_supply),
      "calculated_circulating_supply" =>
        if(burned_supply && total_supply_includes_zero_address_balance?(token, balances),
          do: calculated_circulating_supply(token.total_supply, burned_supply)
        )
    }
  end

  # `[%{address_hash, value, block_number}]` in the order of
  # `SmartContract.burn_address_hashes/0`, for the burn addresses with a fetched
  # balance, with the raw value as an integer
  defp indexed_burn_address_balances(burn_address_balances) do
    Enum.flat_map(SmartContract.burn_address_hashes(), fn address_hash ->
      case Map.fetch(burn_address_balances, address_hash) do
        {:ok, %{value: %Decimal{} = value, block_number: block_number}} ->
          [%{address_hash: address_hash, value: Decimal.to_integer(value), block_number: block_number}]

        _not_fetched ->
          []
      end
    end)
  end

  defp total_supply_includes_zero_address_balance?(%Token{total_supply_updated_at_block: nil}, _balances), do: false

  defp total_supply_includes_zero_address_balance?(%Token{total_supply_updated_at_block: total_supply_block}, balances) do
    {:ok, zero_address_hash} = Hash.Address.cast(SmartContract.burn_address_hash_string())

    Enum.any?(balances, &(&1.address_hash == zero_address_hash and &1.block_number <= total_supply_block))
  end

  defp render_burn_address_balance(%{address_hash: address_hash, value: value}) do
    %{"address_hash" => Address.checksum(address_hash), "value" => Integer.to_string(value)}
  end

  # `totalSupply()` already excludes the tokens burned by the contract itself, so
  # only the balances still held by the burn addresses are subtracted. When they
  # exceed the total supply there is no meaningful value.
  defp calculated_circulating_supply(%Decimal{} = total_supply, burned_supply) when is_integer(burned_supply) do
    circulating_supply = Decimal.to_integer(total_supply) - burned_supply

    if circulating_supply >= 0, do: Integer.to_string(circulating_supply)
  end

  defp calculated_circulating_supply(_total_supply, _burned_supply), do: nil

  @doc """
    Internal json rendering function
  """
  def prepare_token_instance(instance, token) do
    %{
      "id" => instance.token_id,
      "metadata" => instance.metadata,
      "owner" => token_instance_owner(instance.is_unique, instance),
      "token" => render("token.json", %{token: token}),
      "external_app_url" => NFTHelper.external_url(instance),
      "animation_url" => instance.metadata && NFTHelper.retrieve_image(instance.metadata["animation_url"]),
      "image_url" => instance.metadata && NFTHelper.get_media_src(instance.metadata, false),
      "is_unique" => instance.is_unique,
      "thumbnails" => instance.thumbnails,
      "media_type" => instance.media_type,
      "media_url" => Instance.get_media_url_from_metadata_for_nft_media_handler(instance.metadata),
      "image_media_type" => Instance.mime_to_media_category(instance.image_type),
      "animation_media_type" => Instance.mime_to_media_category(instance.animation_type)
    }
  end

  defp token_instance_owner(false, _instance), do: nil
  defp token_instance_owner(nil, _instance), do: nil

  defp token_instance_owner(_is_unique, %Instance{owner: %NotLoaded{}} = instance),
    do: Helper.address_with_info(nil, nil, instance.owner_address_hash, false)

  defp token_instance_owner(_is_unique, %Instance{owner: nil} = instance),
    do: Helper.address_with_info(nil, nil, instance.owner_address_hash, false)

  defp token_instance_owner(_is_unique, instance),
    do: instance.owner && Helper.address_with_info(nil, instance.owner, instance.owner.hash, false)

  defp prepare_holders_count(nil), do: nil
  defp prepare_holders_count(count) when count < 0, do: prepare_holders_count(0)
  defp prepare_holders_count(count), do: to_string(count)

  defp maybe_append_bridged_info(map, token) do
    if BridgedToken.enabled?() do
      (token && Map.put(map, "is_bridged", token.bridged || false)) || map
    else
      map
    end
  end

  case @chain_type do
    :filecoin ->
      defp chain_type_fields(result, params) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.FilecoinView.put_filecoin_robust_address(result, params)
      end

    :zilliqa ->
      defp chain_type_fields(result, params) do
        # credo:disable-for-next-line Credo.Check.Design.AliasUsage
        BlockScoutWeb.API.V2.ZilliqaView.extend_token_json_response(result, params.address)
      end

    _ ->
      defp chain_type_fields(result, _params) do
        result
      end
  end
end
