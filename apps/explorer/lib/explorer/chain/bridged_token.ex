defmodule Explorer.Chain.BridgedToken do
  @moduledoc """
    Represents a bridged token.
  """
  use Explorer.Schema

  import Ecto.Changeset
  import EthereumJSONRPC, only: [json_rpc: 2]

  import Ecto.Query,
    only: [
      from: 2,
      limit: 2,
      where: 2
    ]

  alias ABI.{TypeDecoder, TypeEncoder}
  alias Ecto.Changeset
  alias EthereumJSONRPC.Contract
  alias Explorer.{Chain, PagingOptions, Repo, SortingHelper}

  alias Explorer.Chain.{
    Address,
    BridgedToken,
    Hash,
    InternalTransaction,
    Search,
    Token,
    Transaction
  }

  require Logger

  # TODO: Consider using the `EthereumJSONRPC.ERC20` module to retrieve token metadata

  @default_paging_options %PagingOptions{page_size: 50}
  # keccak 256 from name()
  @name_signature "0x06fdde03"
  # 95d89b41 = keccak256(symbol())
  @symbol_signature "0x95d89b41"
  # keccak 256 from decimals()
  @decimals_signature "0x313ce567"
  # keccak 256 from totalSupply()
  @total_supply_signature "0x18160ddd"
  # keccak 256 from token0()
  @token0_signature "0x0dfe1681"
  # keccak 256 from token1()
  @token1_signature "0xd21220a7"

  @derive {Poison.Encoder,
           except: [
             :__meta__,
             :home_token_contract_address,
             :inserted_at,
             :updated_at
           ]}

  @derive {Jason.Encoder,
           except: [
             :__meta__,
             :home_token_contract_address,
             :inserted_at,
             :updated_at
           ]}

  @typedoc """
  * `foreign_chain_id` - chain ID of a foreign token
  * `foreign_token_contract_address_hash` - Foreign token's contract hash
  * `home_token_contract_address` - The `t:Address.t/0` of the home token's contract
  * `home_token_contract_address_hash` - Home token's contract hash foreign key
  * `custom_metadata` - Arbitrary string with custom metadata. For instance, tokens/weights for Balance tokens
  * `custom_cap` - Custom capitalization for this token
  * `lp_token` - Boolean flag: LP token or not
  * `type` - omni/amb
  """
  @primary_key false
  typed_schema "bridged_tokens" do
    field(:foreign_chain_id, :decimal)
    field(:foreign_token_contract_address_hash, Hash.Address)
    field(:custom_metadata, :string)
    field(:custom_cap, :decimal)
    field(:lp_token, :boolean)
    field(:type, :string)
    field(:exchange_rate, :decimal)

    belongs_to(
      :home_token_contract_address,
      Token,
      foreign_key: :home_token_contract_address_hash,
      primary_key: true,
      references: :contract_address_hash,
      type: Hash.Address,
      null: false
    )

    timestamps()
  end

  @required_attrs ~w(home_token_contract_address_hash)a
  @optional_attrs ~w(foreign_chain_id foreign_token_contract_address_hash custom_metadata custom_cap boolean type exchange_rate)a

  @doc false
  def changeset(%BridgedToken{} = bridged_token, params \\ %{}) do
    bridged_token
    |> cast(params, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> foreign_key_constraint(:home_token_contract_address)
    |> unique_constraint(:home_token_contract_address_hash)
  end

  def get_unprocessed_mainnet_lp_tokens_list do
    query =
      from(bt in BridgedToken,
        where: bt.foreign_chain_id == ^1,
        where: is_nil(bt.lp_token) or bt.lp_token == true,
        select: bt
      )

    query
    |> Repo.all()
  end

  def necessary_envs_passed? do
    config = Application.get_env(:explorer, __MODULE__)
    eth_omni_bridge_mediator = config[:eth_omni_bridge_mediator]
    bsc_omni_bridge_mediator = config[:bsc_omni_bridge_mediator]
    poa_omni_bridge_mediator = config[:poa_omni_bridge_mediator]

    (eth_omni_bridge_mediator && eth_omni_bridge_mediator !== "") ||
      (bsc_omni_bridge_mediator && bsc_omni_bridge_mediator !== "") ||
      (poa_omni_bridge_mediator && poa_omni_bridge_mediator !== "")
  end

  def enabled? do
    Application.get_env(:explorer, __MODULE__)[:enabled]
  end

  @doc """
  Returns a list of token addresses `t:Address.t/0`s that don't have an
  bridged property revealed.
  """
  def unprocessed_token_addresses_to_reveal_bridged_tokens do
    query =
      from(t in Token,
        where: is_nil(t.bridged),
        select: t.contract_address_hash
      )

    Repo.stream_reduce(query, [], &[&1 | &2])
  end

  @doc """
  Processes AMB tokens from mediators addresses provided
  """
  def process_amb_tokens do
    amb_bridge_mediators_var = Application.get_env(:explorer, __MODULE__)[:amb_bridge_mediators]
    amb_bridge_mediators = (amb_bridge_mediators_var && String.split(amb_bridge_mediators_var, ",")) || []

    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    foreign_json_rpc = Application.get_env(:explorer, __MODULE__)[:foreign_json_rpc]

    eth_call_foreign_json_rpc_named_arguments =
      compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)

    try do
      amb_bridge_mediators
      |> Enum.each(fn amb_bridge_mediator_hash ->
        with {:ok, bridge_contract_hash_resp} <-
               get_bridge_contract_hash(amb_bridge_mediator_hash, json_rpc_named_arguments),
             bridge_contract_hash <- decode_contract_address_hash_response(bridge_contract_hash_resp),
             {:ok, destination_chain_id_resp} <-
               get_destination_chain_id(bridge_contract_hash, json_rpc_named_arguments),
             foreign_chain_id <- decode_contract_integer_response(destination_chain_id_resp),
             {:ok, home_token_contract_hash_resp} <-
               get_erc677_token_hash(amb_bridge_mediator_hash, json_rpc_named_arguments),
             home_token_contract_hash_string <- decode_contract_address_hash_response(home_token_contract_hash_resp),
             {:ok, home_token_contract_hash} <- Chain.string_to_address_hash(home_token_contract_hash_string),
             {:ok, foreign_mediator_contract_hash_resp} <-
               get_foreign_mediator_contract_hash(amb_bridge_mediator_hash, json_rpc_named_arguments),
             foreign_mediator_contract_hash <-
               decode_contract_address_hash_response(foreign_mediator_contract_hash_resp),
             {:ok, foreign_token_contract_hash_resp} <-
               get_erc677_token_hash(foreign_mediator_contract_hash, eth_call_foreign_json_rpc_named_arguments),
             foreign_token_contract_hash_string <-
               decode_contract_address_hash_response(foreign_token_contract_hash_resp),
             {:ok, foreign_token_contract_hash} <- Chain.string_to_address_hash(foreign_token_contract_hash_string) do
          insert_bridged_token_metadata(home_token_contract_hash, %{
            foreign_chain_id: foreign_chain_id,
            foreign_token_address_hash: foreign_token_contract_hash,
            custom_metadata: nil,
            custom_cap: nil,
            lp_token: nil,
            type: "amb"
          })

          set_token_bridged_status(home_token_contract_hash, true)
        else
          result ->
            Logger.debug([
              "failed to fetch metadata for token bridged with AMB mediator #{amb_bridge_mediator_hash}",
              inspect(result)
            ])
        end
      end)
    rescue
      _ ->
        :ok
    end

    :ok
  end

  @doc """
  Fetches bridged tokens metadata from OmniBridge.
  """
  def fetch_omni_bridged_tokens_metadata(token_addresses) do
    Enum.each(token_addresses, fn token_address_hash ->
      created_from_internal_transaction_success_query =
        Address.creation_internal_transaction_query(token_address_hash)

      created_from_internal_transaction_success =
        created_from_internal_transaction_success_query
        |> Repo.one()

      created_from_transaction_query =
        from(
          t in Transaction,
          where: t.created_contract_address_hash == ^token_address_hash
        )

      created_from_transaction =
        created_from_transaction_query
        |> Repo.all()
        |> Enum.count() > 0

      created_from_internal_transaction_query =
        from(
          it in InternalTransaction,
          where: it.created_contract_address_hash == ^token_address_hash
        )

      created_from_internal_transaction =
        created_from_internal_transaction_query
        |> Repo.all()
        |> Enum.count() > 0

      cond do
        created_from_transaction ->
          set_token_bridged_status(token_address_hash, false)

        created_from_internal_transaction && !created_from_internal_transaction_success ->
          set_token_bridged_status(token_address_hash, false)

        created_from_internal_transaction && created_from_internal_transaction_success ->
          proceed_with_set_omni_status(token_address_hash, created_from_internal_transaction_success)

        true ->
          :ok
      end
    end)

    :ok
  end

  defp proceed_with_set_omni_status(token_address_hash, created_from_internal_transaction_success) do
    {:ok, eth_omni_status} =
      extract_omni_bridged_token_metadata_wrapper(
        token_address_hash,
        created_from_internal_transaction_success,
        :eth_omni_bridge_mediator
      )

    {:ok, bsc_omni_status} =
      if eth_omni_status do
        {:ok, false}
      else
        extract_omni_bridged_token_metadata_wrapper(
          token_address_hash,
          created_from_internal_transaction_success,
          :bsc_omni_bridge_mediator
        )
      end

    {:ok, poa_omni_status} =
      if eth_omni_status || bsc_omni_status do
        {:ok, false}
      else
        extract_omni_bridged_token_metadata_wrapper(
          token_address_hash,
          created_from_internal_transaction_success,
          :poa_omni_bridge_mediator
        )
      end

    if !eth_omni_status && !bsc_omni_status && !poa_omni_status do
      set_token_bridged_status(token_address_hash, false)
    end
  end

  defp extract_omni_bridged_token_metadata_wrapper(
         token_address_hash,
         created_from_internal_transaction_success,
         mediator
       ) do
    omni_bridge_mediator = Application.get_env(:explorer, __MODULE__)[mediator]
    %{transaction_hash: transaction_hash} = created_from_internal_transaction_success

    if omni_bridge_mediator && omni_bridge_mediator !== "" do
      {:ok, omni_bridge_mediator_hash} = Chain.string_to_address_hash(omni_bridge_mediator)

      created_by_amb_mediator_query =
        from(
          it in InternalTransaction,
          where: it.transaction_hash == ^transaction_hash,
          where: it.to_address_hash == ^omni_bridge_mediator_hash
        )

      created_by_amb_mediator =
        created_by_amb_mediator_query
        |> Repo.all()

      if Enum.empty?(created_by_amb_mediator) do
        {:ok, false}
      else
        extract_omni_bridged_token_metadata(
          token_address_hash,
          omni_bridge_mediator,
          omni_bridge_mediator_hash
        )

        {:ok, true}
      end
    else
      {:ok, false}
    end
  end

  defp extract_omni_bridged_token_metadata(token_address_hash, omni_bridge_mediator, omni_bridge_mediator_hash) do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)

    with {:ok, _} <-
           get_token_interfaces_version_signature(token_address_hash, json_rpc_named_arguments),
         {:ok, foreign_token_address_abi_encoded} <-
           get_foreign_token_address(omni_bridge_mediator, token_address_hash, json_rpc_named_arguments),
         {:ok, bridge_contract_hash_resp} <-
           get_bridge_contract_hash(omni_bridge_mediator_hash, json_rpc_named_arguments) do
      foreign_token_address_hash_string = decode_contract_address_hash_response(foreign_token_address_abi_encoded)
      {:ok, foreign_token_address_hash} = Chain.string_to_address_hash(foreign_token_address_hash_string)

      multi_token_bridge_hash_string = decode_contract_address_hash_response(bridge_contract_hash_resp)

      {:ok, foreign_chain_id_abi_encoded} =
        get_destination_chain_id(multi_token_bridge_hash_string, json_rpc_named_arguments)

      foreign_chain_id = decode_contract_integer_response(foreign_chain_id_abi_encoded)

      foreign_json_rpc = Application.get_env(:explorer, __MODULE__)[:foreign_json_rpc]

      custom_metadata =
        if foreign_chain_id == 1 do
          get_bridged_token_custom_metadata(foreign_token_address_hash, json_rpc_named_arguments, foreign_json_rpc)
        else
          nil
        end

      bridged_token_metadata = %{
        foreign_chain_id: foreign_chain_id,
        foreign_token_address_hash: foreign_token_address_hash,
        custom_metadata: custom_metadata,
        custom_cap: nil,
        lp_token: nil,
        type: "omni"
      }

      insert_bridged_token_metadata(token_address_hash, bridged_token_metadata)

      set_token_bridged_status(token_address_hash, true)
    end
  end

  defp get_bridge_contract_hash(mediator_hash, json_rpc_named_arguments) do
    # keccak 256 from bridgeContract()
    bridge_contract_signature = "0xcd596583"

    perform_eth_call_request(bridge_contract_signature, mediator_hash, json_rpc_named_arguments)
  end

  defp get_erc677_token_hash(mediator_hash, json_rpc_named_arguments) do
    # keccak 256 from erc677token()
    erc677_token_signature = "0x18d8f9c9"

    perform_eth_call_request(erc677_token_signature, mediator_hash, json_rpc_named_arguments)
  end

  defp get_foreign_mediator_contract_hash(mediator_hash, json_rpc_named_arguments) do
    # keccak 256 from mediatorContractOnOtherSide()
    mediator_contract_on_other_side_signature = "0x871c0760"

    perform_eth_call_request(mediator_contract_on_other_side_signature, mediator_hash, json_rpc_named_arguments)
  end

  defp get_destination_chain_id(bridge_contract_hash, json_rpc_named_arguments) do
    # keccak 256 from destinationChainId()
    destination_chain_id_signature = "0xb0750611"

    perform_eth_call_request(destination_chain_id_signature, bridge_contract_hash, json_rpc_named_arguments)
  end

  defp get_token_interfaces_version_signature(token_address_hash, json_rpc_named_arguments) do
    # keccak 256 from getTokenInterfacesVersion()
    get_token_interfaces_version_signature = "0x859ba28c"

    perform_eth_call_request(get_token_interfaces_version_signature, token_address_hash, json_rpc_named_arguments)
  end

  defp get_foreign_token_address(omni_bridge_mediator, token_address_hash, json_rpc_named_arguments) do
    # keccak 256 from foreignTokenAddress(address)
    foreign_token_address_signature = "0x47ac7d6a"

    token_address_hash_abi_encoded =
      [token_address_hash.bytes]
      |> TypeEncoder.encode([:address])
      |> Base.encode16()

    foreign_token_address_method = foreign_token_address_signature <> token_address_hash_abi_encoded

    perform_eth_call_request(foreign_token_address_method, omni_bridge_mediator, json_rpc_named_arguments)
  end

  defp perform_eth_call_request(method, destination, json_rpc_named_arguments)
       when not is_nil(json_rpc_named_arguments) do
    method
    |> Contract.eth_call_request(destination, 1, nil, nil)
    |> json_rpc(json_rpc_named_arguments)
  end

  defp perform_eth_call_request(_method, _destination, json_rpc_named_arguments)
       when is_nil(json_rpc_named_arguments) do
    :error
  end

  def decode_contract_address_hash_response(resp) do
    case resp do
      "0x000000000000000000000000" <> address ->
        "0x" <> address

      _ ->
        nil
    end
  end

  def decode_contract_integer_response(resp) do
    case resp do
      "0x" <> integer_encoded ->
        {integer_value, _} = Integer.parse(integer_encoded, 16)
        integer_value

      _ ->
        nil
    end
  end

  defp set_token_bridged_status(token_address_hash, status) do
    case Repo.get(Token, token_address_hash) do
      %{bridged: bridged} = target_token ->
        if !bridged do
          token = Changeset.change(target_token, bridged: status)

          Repo.update(token)
        end

      _ ->
        :ok
    end
  end

  defp insert_bridged_token_metadata(token_address_hash, %{
         foreign_chain_id: foreign_chain_id,
         foreign_token_address_hash: foreign_token_address_hash,
         custom_metadata: custom_metadata,
         custom_cap: custom_cap,
         lp_token: lp_token,
         type: type
       }) do
    target_token = Repo.get(Token, token_address_hash)

    if target_token do
      {:ok, _} =
        Repo.insert(
          %BridgedToken{
            home_token_contract_address_hash: token_address_hash,
            foreign_chain_id: foreign_chain_id,
            foreign_token_contract_address_hash: foreign_token_address_hash,
            custom_metadata: custom_metadata,
            custom_cap: custom_cap,
            lp_token: lp_token,
            type: type
          },
          on_conflict: :nothing
        )
    end
  end

  # Fetches custom metadata for bridged tokens from the node.
  # Currently, gets Balancer token composite tokens with their weights
  # from foreign chain
  defp get_bridged_token_custom_metadata(foreign_token_address_hash, json_rpc_named_arguments, foreign_json_rpc)
       when not is_nil(foreign_json_rpc) and foreign_json_rpc !== "" do
    eth_call_foreign_json_rpc_named_arguments =
      compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)

    balancer_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments) ||
      sushiswap_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments)
  end

  defp get_bridged_token_custom_metadata(_foreign_token_address_hash, _json_rpc_named_arguments, foreign_json_rpc)
       when is_nil(foreign_json_rpc) do
    nil
  end

  defp get_bridged_token_custom_metadata(_foreign_token_address_hash, _json_rpc_named_arguments, foreign_json_rpc)
       when foreign_json_rpc == "" do
    nil
  end

  defp balancer_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments) do
    # keccak 256 from getCurrentTokens()
    get_current_tokens_signature = "0xcc77828d"

    case get_current_tokens_signature
         |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
         |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
      {:ok, "0x"} ->
        nil

      {:ok, "0x" <> balancer_current_tokens_encoded} ->
        [balancer_current_tokens] =
          try do
            balancer_current_tokens_encoded
            |> Base.decode16!(case: :mixed)
            |> TypeDecoder.decode_raw([{:array, :address}])
          rescue
            _ -> []
          end

        bridged_token_custom_metadata =
          parse_bridged_token_custom_metadata(
            balancer_current_tokens,
            eth_call_foreign_json_rpc_named_arguments,
            foreign_token_address_hash
          )

        tokens_and_weights(bridged_token_custom_metadata)

      _ ->
        nil
    end
  end

  defp tokens_and_weights(bridged_token_custom_metadata) do
    with true <- is_map(bridged_token_custom_metadata),
         tokens = Map.get(bridged_token_custom_metadata, :tokens),
         weights = Map.get(bridged_token_custom_metadata, :weights),
         false <- tokens == "" do
      if weights !== "", do: "#{tokens} #{weights}", else: tokens
    else
      _ -> nil
    end
  end

  defp sushiswap_custom_metadata(foreign_token_address_hash, eth_call_foreign_json_rpc_named_arguments) do
    with {:ok, "0x" <> token0_encoded} <-
           @token0_signature
           |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         {:ok, "0x" <> token1_encoded} <-
           @token1_signature
           |> Contract.eth_call_request(foreign_token_address_hash, 2, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         token0_hash <- parse_contract_response(token0_encoded, :address),
         token1_hash <- parse_contract_response(token1_encoded, :address),
         {:ok, token0_hash} <- Hash.Address.cast(token0_hash),
         {:ok, token1_hash} <- Hash.Address.cast(token1_hash),
         token0_hash_str <- to_string(token0_hash),
         token1_hash_str <- to_string(token1_hash),
         {:ok, "0x" <> token0_name_encoded} <-
           @name_signature
           |> Contract.eth_call_request(token0_hash_str, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         {:ok, "0x" <> token1_name_encoded} <-
           @name_signature
           |> Contract.eth_call_request(token1_hash_str, 2, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         {:ok, "0x" <> token0_symbol_encoded} <-
           @symbol_signature
           |> Contract.eth_call_request(token0_hash_str, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         {:ok, "0x" <> token1_symbol_encoded} <-
           @symbol_signature
           |> Contract.eth_call_request(token1_hash_str, 2, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
      token0_name = parse_contract_response(token0_name_encoded, :string, {:bytes, 32})
      token1_name = parse_contract_response(token1_name_encoded, :string, {:bytes, 32})
      token0_symbol = parse_contract_response(token0_symbol_encoded, :string, {:bytes, 32})
      token1_symbol = parse_contract_response(token1_symbol_encoded, :string, {:bytes, 32})

      "#{token0_name}/#{token1_name} (#{token0_symbol}/#{token1_symbol})"
    else
      _ ->
        nil
    end
  end

  def calc_lp_tokens_total_liquidity do
    json_rpc_named_arguments = Application.get_env(:explorer, :json_rpc_named_arguments)
    foreign_json_rpc = Application.get_env(:explorer, __MODULE__)[:foreign_json_rpc]
    bridged_mainnet_tokens_list = BridgedToken.get_unprocessed_mainnet_lp_tokens_list()

    Enum.each(bridged_mainnet_tokens_list, fn bridged_token ->
      case calc_sushiswap_lp_tokens_cap(
             bridged_token.home_token_contract_address_hash,
             bridged_token.foreign_token_contract_address_hash,
             json_rpc_named_arguments,
             foreign_json_rpc
           ) do
        {:ok, new_custom_cap} ->
          bridged_token
          |> Changeset.change(%{custom_cap: new_custom_cap, lp_token: true})
          |> Repo.update()

        {:error, :not_lp_token} ->
          bridged_token
          |> Changeset.change(%{lp_token: false})
          |> Repo.update()
      end
    end)

    Logger.debug(fn -> "Total liquidity fetched for LP tokens" end)
  end

  defp calc_sushiswap_lp_tokens_cap(
         home_token_contract_address_hash,
         foreign_token_address_hash,
         json_rpc_named_arguments,
         foreign_json_rpc
       ) do
    eth_call_foreign_json_rpc_named_arguments =
      compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)

    # keccak 256 from getReserves()
    get_reserves_signature = "0x0902f1ac"

    with {:ok, "0x" <> get_reserves_encoded} <-
           get_reserves_signature
           |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
         {:ok, "0x" <> home_token_total_supply_encoded} <-
           @total_supply_signature
           |> Contract.eth_call_request(home_token_contract_address_hash, 1, nil, nil)
           |> json_rpc(json_rpc_named_arguments),
         [reserve0, reserve1, _] <-
           parse_contract_response(get_reserves_encoded, [{:uint, 112}, {:uint, 112}, {:uint, 32}]),
         {:ok, token0_cap_usd} <-
           get_lp_token_cap(
             home_token_total_supply_encoded,
             @token0_signature,
             reserve0,
             foreign_token_address_hash,
             eth_call_foreign_json_rpc_named_arguments
           ),
         {:ok, token1_cap_usd} <-
           get_lp_token_cap(
             home_token_total_supply_encoded,
             @token1_signature,
             reserve1,
             foreign_token_address_hash,
             eth_call_foreign_json_rpc_named_arguments
           ) do
      total_lp_cap = Decimal.add(token0_cap_usd, token1_cap_usd)
      {:ok, total_lp_cap}
    else
      _ ->
        {:error, :not_lp_token}
    end
  end

  defp get_lp_token_cap(
         home_token_total_supply_encoded,
         token_signature,
         reserve,
         foreign_token_address_hash,
         eth_call_foreign_json_rpc_named_arguments
       ) do
    home_token_total_supply =
      home_token_total_supply_encoded
      |> parse_contract_response({:uint, 256})
      |> Decimal.new()

    case token_signature
         |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
         |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
      {:ok, "0x" <> token_encoded} ->
        with token_hash <- parse_contract_response(token_encoded, :address),
             {:ok, token_hash} <- Hash.Address.cast(token_hash),
             token_hash_str <- to_string(token_hash),
             {:ok, "0x" <> token_decimals_encoded} <-
               @decimals_signature
               |> Contract.eth_call_request(token_hash_str, 1, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments),
             {:ok, "0x" <> foreign_token_total_supply_encoded} <-
               @total_supply_signature
               |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
               |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
          token_decimals = parse_contract_response(token_decimals_encoded, {:uint, 256})

          foreign_token_total_supply =
            foreign_token_total_supply_encoded
            |> parse_contract_response({:uint, 256})
            |> Decimal.new()

          token_decimals_divider =
            10
            |> :math.pow(token_decimals)
            |> Decimal.from_float()

          token_cap =
            reserve
            |> Decimal.div(foreign_token_total_supply)
            |> Decimal.mult(home_token_total_supply)
            |> Decimal.div(token_decimals_divider)

          token = Token.get_by_contract_address_hash(token_hash_str, [])

          token_cap_usd =
            if token && token.fiat_value do
              token.fiat_value
              |> Decimal.mult(token_cap)
            else
              0
            end

          {:ok, token_cap_usd}
        else
          _ -> :error
        end
    end
  end

  defp parse_contract_response(abi_encoded_value, types) when is_list(types) do
    values =
      try do
        abi_encoded_value
        |> Base.decode16!(case: :mixed)
        |> TypeDecoder.decode_raw(types)
      rescue
        _ -> [nil]
      end

    values
  end

  defp parse_contract_response(abi_encoded_value, type, emergency_type \\ nil) do
    [value] =
      try do
        [res] = decode_contract_response(abi_encoded_value, type)

        [convert_binary_to_string(res, type)]
      rescue
        _ ->
          if emergency_type do
            try do
              [res] = decode_contract_response(abi_encoded_value, emergency_type)

              [convert_binary_to_string(res, emergency_type)]
            rescue
              _ ->
                [nil]
            end
          else
            [nil]
          end
      end

    value
  end

  defp decode_contract_response(abi_encoded_value, type) do
    abi_encoded_value
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw([type])
  end

  defp convert_binary_to_string(binary, type) do
    case type do
      {:bytes, _} ->
        binary_to_string(binary)

      _ ->
        binary
    end
  end

  defp compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, foreign_json_rpc)
       when foreign_json_rpc != "" do
    {_, eth_call_foreign_json_rpc_named_arguments} =
      Keyword.get_and_update(json_rpc_named_arguments, :transport_options, fn transport_options ->
        {_, updated_transport_options} =
          update_transport_options_set_foreign_json_rpc(transport_options, foreign_json_rpc)

        {transport_options, updated_transport_options}
      end)

    eth_call_foreign_json_rpc_named_arguments
  end

  defp compose_foreign_json_rpc_named_arguments(_json_rpc_named_arguments, foreign_json_rpc)
       when foreign_json_rpc == "" do
    nil
  end

  defp compose_foreign_json_rpc_named_arguments(json_rpc_named_arguments, _foreign_json_rpc)
       when is_nil(json_rpc_named_arguments) do
    nil
  end

  defp update_transport_options_set_foreign_json_rpc(transport_options, foreign_json_rpc) do
    {_, updated_transport_options} =
      Keyword.get_and_update(transport_options, :method_to_url, fn method_to_url ->
        {_, updated_method_to_url} =
          Keyword.get_and_update(method_to_url, :eth_call, fn eth_call ->
            {eth_call, :eth_call}
          end)

        {method_to_url, updated_method_to_url}
      end)

    Keyword.get_and_update(updated_transport_options, :eth_call_urls, fn eth_call_urls ->
      {eth_call_urls, [foreign_json_rpc]}
    end)
  end

  defp parse_bridged_token_custom_metadata(
         balancer_current_tokens,
         eth_call_foreign_json_rpc_named_arguments,
         foreign_token_address_hash
       ) do
    balancer_current_tokens
    |> Enum.reduce(%{:tokens => "", :weights => ""}, fn balancer_token_bytes, balancer_tokens_weights ->
      balancer_token_hash_without_0x =
        balancer_token_bytes
        |> Base.encode16(case: :lower)

      balancer_token_hash = "0x" <> balancer_token_hash_without_0x

      case @symbol_signature
           |> Contract.eth_call_request(balancer_token_hash, 1, nil, nil)
           |> json_rpc(eth_call_foreign_json_rpc_named_arguments) do
        {:ok, "0x" <> symbol_encoded} ->
          [symbol] =
            symbol_encoded
            |> Base.decode16!(case: :mixed)
            |> TypeDecoder.decode_raw([:string])

          # f1b8a9b7 = keccak256(getNormalizedWeight(address))
          get_normalized_weight_signature = "0xf1b8a9b7"

          get_normalized_weight_arg_abi_encoded =
            [balancer_token_bytes]
            |> TypeEncoder.encode([:address])
            |> Base.encode16(case: :lower)

          get_normalized_weight_abi_encoded = get_normalized_weight_signature <> get_normalized_weight_arg_abi_encoded

          get_normalized_weight_resp =
            get_normalized_weight_abi_encoded
            |> Contract.eth_call_request(foreign_token_address_hash, 1, nil, nil)
            |> json_rpc(eth_call_foreign_json_rpc_named_arguments)

          parse_balancer_weights(get_normalized_weight_resp, balancer_tokens_weights, symbol)

        _ ->
          nil
      end
    end)
  end

  defp parse_balancer_weights(get_normalized_weight_resp, balancer_tokens_weights, symbol) do
    case get_normalized_weight_resp do
      {:ok, "0x" <> normalized_weight_encoded} ->
        [normalized_weight] =
          try do
            normalized_weight_encoded
            |> Base.decode16!(case: :mixed)
            |> TypeDecoder.decode_raw([{:uint, 256}])
          rescue
            _ ->
              []
          end

        normalized_weight_to_100_perc = calc_normalized_weight_to_100_perc(normalized_weight)

        normalized_weight_in_perc =
          normalized_weight_to_100_perc
          |> div(1_000_000_000_000_000_000)

        current_tokens = Map.get(balancer_tokens_weights, :tokens)
        current_weights = Map.get(balancer_tokens_weights, :weights)

        tokens_value = combine_tokens_value(current_tokens, symbol)
        weights_value = combine_weights_value(current_weights, normalized_weight_in_perc)

        %{:tokens => tokens_value, :weights => weights_value}

      _ ->
        nil
    end
  end

  defp calc_normalized_weight_to_100_perc(normalized_weight) do
    if normalized_weight, do: 100 * normalized_weight, else: 0
  end

  defp combine_tokens_value(current_tokens, symbol) do
    if current_tokens == "", do: symbol, else: current_tokens <> "/" <> symbol
  end

  defp combine_weights_value(current_weights, normalized_weight_in_perc) do
    if current_weights == "",
      do: "#{normalized_weight_in_perc}",
      else: current_weights <> "/" <> "#{normalized_weight_in_perc}"
  end

  defp fetch_top_bridged_tokens(chain_ids, paging_options, filter, sorting, options) do
    bridged_tokens_query =
      __MODULE__
      |> apply_chain_ids_filter(chain_ids)

    base_query =
      from(t in Token.base_token_query(nil, sorting),
        right_join: bt in subquery(bridged_tokens_query),
        on: t.contract_address_hash == bt.home_token_contract_address_hash,
        where: t.total_supply > ^0,
        where: t.bridged,
        select: {t, bt},
        preload: [:contract_address]
      )

    base_query_with_paging =
      base_query
      |> SortingHelper.page_with_sorting(paging_options, sorting, Token.default_sorting())
      |> limit(^paging_options.page_size)

    query =
      if filter && filter !== "" do
        case Search.prepare_search_term(filter) do
          {:some, filter_term} ->
            base_query_with_paging
            |> where(fragment("to_tsvector('english', symbol || ' ' || name) @@ to_tsquery(?)", ^filter_term))

          _ ->
            base_query_with_paging
        end
      else
        base_query_with_paging
      end

    query
    |> Chain.select_repo(options).all()
  end

  @spec list_top_bridged_tokens(String.t()) :: [{Token.t(), BridgedToken.t()}]
  def list_top_bridged_tokens(filter, options \\ []) do
    paging_options = Keyword.get(options, :paging_options, @default_paging_options)
    chain_ids = Keyword.get(options, :chain_ids, nil)
    sorting = Keyword.get(options, :sorting, [])

    fetch_top_bridged_tokens(chain_ids, paging_options, filter, sorting, options)
  end

  defp apply_chain_ids_filter(query, chain_ids) when chain_ids in [[], nil], do: query

  defp apply_chain_ids_filter(query, chain_ids) when is_list(chain_ids),
    do: from(bt in query, where: bt.foreign_chain_id in ^chain_ids)

  def binary_to_string(binary) do
    binary
    |> :binary.bin_to_list()
    |> Enum.filter(fn x -> x != 0 end)
    |> List.to_string()
  end

  def token_display_name_based_on_bridge_destination(name, foreign_chain_id) do
    cond do
      Decimal.compare(foreign_chain_id, 1) == :eq ->
        name
        |> String.replace("on xDai", "from Ethereum")

      Decimal.compare(foreign_chain_id, 56) == :eq ->
        name
        |> String.replace("on xDai", "from BSC")

      true ->
        name
    end
  end

  def token_display_name_based_on_bridge_destination(name, symbol, foreign_chain_id) do
    token_name =
      cond do
        Decimal.compare(foreign_chain_id, 1) == :eq ->
          name
          |> String.replace("on xDai", "from Ethereum")

        Decimal.compare(foreign_chain_id, 56) == :eq ->
          name
          |> String.replace("on xDai", "from BSC")

        true ->
          name
      end

    "#{token_name} (#{symbol})"
  end
end
