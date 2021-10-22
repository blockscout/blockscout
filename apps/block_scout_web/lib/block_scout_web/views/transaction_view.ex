defmodule BlockScoutWeb.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{AccessHelpers, AddressView, BlockView, TabHelpers}
  alias BlockScoutWeb.Cldr.Number
  alias Explorer.{Chain, CustomContractsHelpers, Repo}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.{Address, Block, InternalTransaction, Transaction, Wei}
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.ExchangeRates.Token
  alias Timex.Duration

  import BlockScoutWeb.Gettext
  import BlockScoutWeb.AddressView, only: [from_address_hash: 1, short_token_id: 2]
  import BlockScoutWeb.Tokens.Helpers

  @tabs ["token-transfers", "internal-transactions", "logs", "raw-trace"]

  @token_burning_title "Token Burning"
  @token_minting_title "Token Minting"
  @token_transfer_title "Token Transfer"
  @token_creation_title "Token Creation"

  @token_burning_type :token_burning
  @token_minting_type :token_minting
  @token_creation_type :token_spawning
  @token_transfer_type :token_transfer

  defguardp is_transaction_type(mod) when mod in [InternalTransaction, Transaction]

  defdelegate formatted_timestamp(block), to: BlockView

  def block_number(%Transaction{block_number: nil}), do: gettext("Block Pending")
  def block_number(%Transaction{block: block}), do: [view_module: BlockView, partial: "_link.html", block: block]
  def block_number(%Reward{block: block}), do: [view_module: BlockView, partial: "_link.html", block: block]

  def block_timestamp(%Transaction{block_number: nil, inserted_at: time}), do: time
  def block_timestamp(%Transaction{block: %Block{timestamp: time}}), do: time
  def block_timestamp(%Reward{block: %Block{timestamp: time}}), do: time

  def value_transfer?(%Transaction{input: %{bytes: bytes}}) when bytes in [<<>>, nil] do
    true
  end

  def value_transfer?(_), do: false

  def token_transfer_type(transaction) do
    transaction_with_transfers = Repo.preload(transaction, token_transfers: :token)

    token_transfers_filtered_by_block_hash =
      transaction_with_transfers
      |> Map.get(:token_transfers, [])
      |> Enum.filter(fn token_transfer ->
        token_transfer.block_hash == transaction.block_hash
      end)

    transaction_with_transfers_filtered =
      Map.put(transaction_with_transfers, :token_transfers, token_transfers_filtered_by_block_hash)

    type = Chain.transaction_token_transfer_type(transaction)
    if type, do: {type, transaction_with_transfers_filtered}, else: {nil, transaction_with_transfers_filtered}
  end

  def aggregate_token_transfers(token_transfers) do
    %{
      transfers: {ft_transfers, nft_transfers},
      mintings: {ft_mintings, nft_mintings},
      burnings: {ft_burnings, nft_burnings},
      creations: {ft_creations, nft_creations}
    } =
      token_transfers
      |> Enum.reduce(
        %{
          transfers: {[], []},
          mintings: {[], []},
          burnings: {[], []},
          creations: {[], []}
        },
        fn token_transfer, acc ->
          token_transfer_type = Chain.get_token_transfer_type(token_transfer)

          case token_transfer_type do
            :token_transfer ->
              transfers = aggregate_reducer(token_transfer, acc.transfers)

              %{
                transfers: transfers,
                mintings: acc.mintings,
                burnings: acc.burnings,
                creations: acc.creations
              }

            :token_burning ->
              burnings = aggregate_reducer(token_transfer, acc.burnings)

              %{
                transfers: acc.transfers,
                mintings: acc.mintings,
                burnings: burnings,
                creations: acc.creations
              }

            :token_minting ->
              mintings = aggregate_reducer(token_transfer, acc.mintings)

              %{
                transfers: acc.transfers,
                mintings: mintings,
                burnings: acc.burnings,
                creations: acc.creations
              }

            :token_spawning ->
              creations = aggregate_reducer(token_transfer, acc.creations)

              %{
                transfers: acc.transfers,
                mintings: acc.mintings,
                burnings: acc.burnings,
                creations: creations
              }
          end
        end
      )

    transfers = ft_transfers ++ nft_transfers

    mintings = ft_mintings ++ nft_mintings

    burnings = ft_burnings ++ nft_burnings

    creations = ft_creations ++ nft_creations

    %{transfers: transfers, mintings: mintings, burnings: burnings, creations: creations}
  end

  defp aggregate_reducer(%{amount: amount, amounts: amounts} = token_transfer, {acc1, acc2})
       when is_nil(amount) and is_nil(amounts) do
    new_entry = %{
      token: token_transfer.token,
      amount: nil,
      amounts: [],
      token_id: token_transfer.token_id,
      token_ids: [],
      to_address_hash: token_transfer.to_address_hash,
      from_address_hash: token_transfer.from_address_hash
    }

    {acc1, [new_entry | acc2]}
  end

  defp aggregate_reducer(%{amount: amount, amounts: amounts} = token_transfer, {acc1, acc2})
       when is_nil(amount) and not is_nil(amounts) do
    new_entry = %{
      token: token_transfer.token,
      amount: nil,
      amounts: amounts,
      token_id: nil,
      token_ids: token_transfer.token_ids,
      to_address_hash: token_transfer.to_address_hash,
      from_address_hash: token_transfer.from_address_hash
    }

    {acc1, [new_entry | acc2]}
  end

  defp aggregate_reducer(token_transfer, {acc1, acc2}) do
    new_entry = %{
      token: token_transfer.token,
      amount: token_transfer.amount,
      amounts: [],
      token_id: token_transfer.token_id,
      token_ids: [],
      to_address_hash: token_transfer.to_address_hash,
      from_address_hash: token_transfer.from_address_hash
    }

    existing_entry =
      acc1
      |> Enum.find(fn entry ->
        entry.to_address_hash == token_transfer.to_address_hash &&
          entry.from_address_hash == token_transfer.from_address_hash &&
          entry.token == token_transfer.token
      end)

    new_acc1 =
      if existing_entry do
        acc1
        |> Enum.map(fn entry ->
          if entry.to_address_hash == token_transfer.to_address_hash &&
               entry.from_address_hash == token_transfer.from_address_hash &&
               entry.token == token_transfer.token do
            updated_entry = %{
              entry
              | amount: Decimal.add(new_entry.amount, entry.amount)
            }

            updated_entry
          else
            entry
          end
        end)
      else
        [new_entry | acc1]
      end

    {new_acc1, acc2}
  end

  def token_type_name(type) do
    case type do
      :erc20 -> gettext("ERC-20 ")
      :erc721 -> gettext("ERC-721 ")
      :erc1155 -> gettext("ERC-1155 ")
      _ -> ""
    end
  end

  def processing_time_duration(%Transaction{block: nil}) do
    :pending
  end

  def processing_time_duration(%Transaction{earliest_processing_start: nil}) do
    avg_time = AverageBlockTime.average_block_time()

    if avg_time == {:error, :disabled} do
      :unknown
    else
      avg_time_in_secs =
        avg_time
        |> Duration.to_seconds()

      {:ok, "<= #{avg_time_in_secs} seconds"}
    end
  end

  def processing_time_duration(%Transaction{
        block: %Block{timestamp: end_time},
        earliest_processing_start: earliest_processing_start,
        inserted_at: inserted_at
      }) do
    with {:ok, long_interval} <- humanized_diff(earliest_processing_start, end_time),
         {:ok, short_interval} <- humanized_diff(inserted_at, end_time) do
      {:ok, merge_intervals(short_interval, long_interval)}
    else
      _ ->
        :ignore
    end
  end

  defp merge_intervals(short, long) when short == long, do: short

  defp merge_intervals(short, long) do
    [short_time, short_unit] = String.split(short, " ")
    [long_time, long_unit] = String.split(long, " ")

    if short_unit == long_unit do
      short_time <> "-" <> long_time <> " " <> short_unit
    else
      short <> " - " <> long
    end
  end

  defp humanized_diff(left, right) do
    left
    |> Timex.diff(right, :milliseconds)
    |> Duration.from_milliseconds()
    |> Timex.format_duration(Explorer.Counters.AverageBlockTimeDurationFormat)
    |> case do
      {:error, _} = error -> error
      duration -> {:ok, duration}
    end
  end

  def confirmations(%Transaction{block: block}, named_arguments) when is_list(named_arguments) do
    case block do
      %Block{consensus: true} ->
        {:ok, confirmations} = Chain.confirmations(block, named_arguments)
        BlockScoutWeb.Cldr.Number.to_string!(confirmations, format: "#,###")

      _ ->
        0
    end
  end

  def confirmations_ds_name(blocks_amount_str) do
    case Integer.parse(blocks_amount_str) do
      {blocks_amount, ""} ->
        if rem(blocks_amount, 10) == 1 do
          "block"
        else
          "blocks"
        end

      _ ->
        ""
    end
  end

  def contract_creation?(%Transaction{to_address: nil}), do: true

  def contract_creation?(_), do: false

  #  def utf8_encode() do
  #  end

  def fee(%Transaction{} = transaction) do
    {_, value} = Chain.fee(transaction, :wei)
    value
  end

  def format_gas_limit(gas) do
    Number.to_string!(gas)
  end

  def formatted_fee(%Transaction{} = transaction, opts) do
    transaction
    |> Chain.fee(:wei)
    |> fee_to_denomination(opts)
    |> case do
      {:actual, value} -> value
      {:maximum, value} -> "#{gettext("Max of")} #{value}"
    end
  end

  def transaction_status(transaction) do
    Chain.transaction_to_status(transaction)
  end

  def transaction_revert_reason(transaction) do
    transaction |> Chain.transaction_to_revert_reason() |> decoded_revert_reason(transaction)
  end

  def get_pure_transaction_revert_reason(transaction), do: Chain.transaction_to_revert_reason(transaction)

  def empty_exchange_rate?(exchange_rate) do
    Token.null?(exchange_rate)
  end

  def formatted_status(status) do
    case status do
      :pending -> gettext("Unconfirmed")
      _ -> gettext("Confirmed")
    end
  end

  def formatted_result(status) do
    case status do
      :pending -> gettext("Pending")
      :awaiting_internal_transactions -> gettext("(Awaiting internal transactions for status)")
      :success -> gettext("Success")
      {:error, :awaiting_internal_transactions} -> gettext("Error: (Awaiting internal transactions for reason)")
      # The pool of possible error reasons is unknown or even if it is enumerable, so we can't translate them
      {:error, reason} when is_binary(reason) -> gettext("Error: %{reason}", reason: reason)
    end
  end

  def from_or_to_address?(_token_transfer, nil), do: false

  def from_or_to_address?(%{from_address_hash: from_hash, to_address_hash: to_hash}, %Address{hash: hash}) do
    from_hash == hash || to_hash == hash
  end

  def gas(%type{gas: gas}) when is_transaction_type(type) do
    BlockScoutWeb.Cldr.Number.to_string!(gas)
  end

  def skip_decoding?(transaction) do
    contract_creation?(transaction) || value_transfer?(transaction)
  end

  def decoded_input_data(transaction) do
    Transaction.decoded_input_data(transaction)
  end

  def decoded_revert_reason(revert_reason, transaction) do
    Transaction.decoded_revert_reason(transaction, revert_reason)
  end

  @doc """
  Converts a transaction's gas price to a displayable value.
  """
  def gas_price(%Transaction{gas_price: gas_price}, unit) when unit in ~w(wei gwei ether)a do
    format_wei_value(gas_price, unit)
  end

  def gas_used(%Transaction{gas_used: nil}), do: gettext("Pending")

  def gas_used(%Transaction{gas_used: gas_used}) do
    Number.to_string!(gas_used)
  end

  def gas_used_perc(%Transaction{gas_used: nil}), do: nil

  def gas_used_perc(%Transaction{gas_used: gas_used, gas: gas}) do
    if Decimal.cmp(gas, 0) == :gt do
      gas_used
      |> Decimal.div(gas)
      |> Decimal.mult(100)
      |> Decimal.round(2)
      |> Number.to_string!()
    else
      nil
    end
  end

  def hash(%Transaction{hash: hash}) do
    to_string(hash)
  end

  def involves_contract?(%Transaction{from_address: from_address, to_address: to_address}) do
    AddressView.contract?(from_address) || AddressView.contract?(to_address)
  end

  def involves_token_transfers?(%Transaction{token_transfers: []}), do: false
  def involves_token_transfers?(%Transaction{token_transfers: transfers}) when is_list(transfers), do: true
  def involves_token_transfers?(_), do: false

  def qr_code(%Transaction{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def status_class(transaction) do
    case Chain.transaction_to_status(transaction) do
      :pending -> "tile-status--pending"
      :awaiting_internal_transactions -> "tile-status--awaiting-internal-transactions"
      :success -> "tile-status--success"
      {:error, :awaiting_internal_transactions} -> "tile-status--error--awaiting-internal-transactions"
      {:error, reason} when is_binary(reason) -> "tile-status--error--reason"
    end
  end

  # This is the address to be shown in the to field
  def to_address_hash(%Transaction{to_address_hash: nil, created_contract_address_hash: address_hash}),
    do: address_hash

  def to_address_hash(%Transaction{to_address_hash: address_hash}), do: address_hash

  def transaction_display_type(%Transaction{} = transaction) do
    cond do
      involves_token_transfers?(transaction) ->
        token_transfer_type = get_transaction_type_from_token_transfers(transaction.token_transfers)

        case token_transfer_type do
          @token_minting_type -> gettext(@token_minting_title)
          @token_burning_type -> gettext(@token_burning_title)
          @token_creation_type -> gettext(@token_creation_title)
          @token_transfer_type -> gettext(@token_transfer_title)
        end

      contract_creation?(transaction) ->
        gettext("Contract Creation")

      involves_contract?(transaction) ->
        gettext("Contract Call")

      true ->
        gettext("Transaction")
    end
  end

  def type_suffix(%Transaction{} = transaction) do
    cond do
      involves_token_transfers?(transaction) -> "token-transfer"
      contract_creation?(transaction) -> "contract-creation"
      involves_contract?(transaction) -> "contract-call"
      true -> "transaction"
    end
  end

  @doc """
  Converts a transaction's Wei value to Ether and returns a formatted display value.

  ## Options

  * `:include_label` - Boolean. Defaults to true. Flag for displaying unit with value.
  """
  def value(%mod{value: value}, opts \\ []) when is_transaction_type(mod) do
    include_label? = Keyword.get(opts, :include_label, true)
    format_wei_value(value, :ether, include_unit_label: include_label?)
  end

  def format_wei_value(value) do
    format_wei_value(value, :ether, include_unit_label: false)
  end

  defp fee_to_denomination({fee_type, fee}, opts) do
    denomination = Keyword.get(opts, :denomination)
    include_label? = Keyword.get(opts, :include_label, true)
    {fee_type, format_wei_value(Wei.from(fee, :wei), denomination, include_unit_label: include_label?)}
  end

  @doc """
  Get the current tab name/title from the request path and possible tab names.

  The tabs on mobile are represented by a dropdown list, which has a title. This title is the currently selected tab name. This function returns that name, properly gettext'ed.

  The list of possible tab names for this page is represented by the attribute @tab.

  Raises an error if there is no match, so a developer of a new tab must include it in the list.

  """
  def current_tab_name(request_path) do
    @tabs
    |> Enum.filter(&TabHelpers.tab_active?(&1, request_path))
    |> tab_name()
  end

  defp tab_name(["token-transfers"]), do: gettext("Token Transfers")
  defp tab_name(["internal-transactions"]), do: gettext("Internal Transactions")
  defp tab_name(["logs"]), do: gettext("Logs")
  defp tab_name(["raw-trace"]), do: gettext("Raw Trace")

  defp get_transaction_type_from_token_transfers(token_transfers) do
    token_transfers_types =
      token_transfers
      |> Enum.map(fn token_transfer ->
        Chain.get_token_transfer_type(token_transfer)
      end)

    burnings_count =
      Enum.count(token_transfers_types, fn token_transfers_type -> token_transfers_type == @token_burning_type end)

    mintings_count =
      Enum.count(token_transfers_types, fn token_transfers_type -> token_transfers_type == @token_minting_type end)

    creations_count =
      Enum.count(token_transfers_types, fn token_transfers_type -> token_transfers_type == @token_creation_type end)

    cond do
      Enum.count(token_transfers_types) == burnings_count -> @token_burning_type
      Enum.count(token_transfers_types) == mintings_count -> @token_minting_type
      Enum.count(token_transfers_types) == creations_count -> @token_creation_type
      true -> @token_transfer_type
    end
  end

  defp amb_tx?(hash) do
    Chain.amb_eth_tx?(hash) || Chain.amb_bsc_tx?(hash) || Chain.amb_poa_tx?(hash)
  end

  defp show_alm_link?(hash) do
    amb_tx?(hash)
  end

  defp get_alm_app_link(hash) do
    cond do
      Chain.amb_eth_tx?(hash) == true -> "alm-xdai.herokuapp.com"
      Chain.amb_bsc_tx?(hash) == true -> "alm-bsc-xdai.herokuapp.com"
      Chain.amb_poa_tx?(hash) == true -> "alm-poa-xdai.herokuapp.com"
      true -> nil
    end
  end

  defp show_tenderly_link? do
    System.get_env("SHOW_TENDERLY_LINK") == "true"
  end

  defp tenderly_chain_path do
    System.get_env("TENDERLY_CHAIN_PATH") || "/"
  end

  def get_max_length do
    string_value = Application.get_env(:block_scout_web, :max_length_to_show_string_without_trimming)

    case Integer.parse(string_value) do
      {integer, ""} -> integer
      _ -> 0
    end
  end

  def trim(length, string) do
    %{show: String.slice(string, 0..length), hide: String.slice(string, (length + 1)..String.length(string))}
  end

  defp template_to_string(template) when is_list(template) do
    template_to_string(Enum.at(template, 1))
  end

  defp template_to_string(template) when is_tuple(template) do
    safe_to_string(template)
  end
end
