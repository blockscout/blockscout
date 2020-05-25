defmodule BlockScoutWeb.TransactionView do
  use BlockScoutWeb, :view

  alias BlockScoutWeb.{AddressView, BlockView, TabHelpers}
  alias BlockScoutWeb.Cldr.Number
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.{Address, Block, InternalTransaction, Transaction, Wei}
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.ExchangeRates.Token
  alias Timex.Duration

  import BlockScoutWeb.Gettext
  import BlockScoutWeb.Tokens.Helpers

  @tabs ["token_transfers", "internal_transactions", "logs", "raw_trace"]

  {:ok, burn_address_hash} = Chain.string_to_address_hash("0x0000000000000000000000000000000000000000")
  @burn_address_hash burn_address_hash

  @token_burning_title "Token Burning"
  @token_minting_title "Token Minting"
  @token_transfer_title "Token Transfer"

  @token_burning_type "token-burning"
  @token_minting_type "token-minting"
  @token_transfer_type "token-transfer"

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

    type = Chain.transaction_token_transfer_type(transaction)
    if type, do: {type, transaction_with_transfers}, else: {nil, transaction_with_transfers}
  end

  def aggregate_token_transfers(token_transfers) do
    {transfers, nft_transfers} =
      token_transfers
      |> Enum.reduce({%{}, []}, fn token_transfer, acc ->
        if token_transfer.to_address_hash != @burn_address_hash &&
             token_transfer.from_address_hash != @burn_address_hash do
          aggregate_reducer(token_transfer, acc)
        else
          acc
        end
      end)

    final_transfers = Map.values(transfers)

    final_transfers ++ nft_transfers
  end

  def aggregate_token_mintings(token_transfers) do
    {transfers, nft_transfers} =
      token_transfers
      |> Enum.reduce({%{}, []}, fn token_transfer, acc ->
        if token_transfer.from_address_hash == @burn_address_hash do
          aggregate_reducer(token_transfer, acc)
        else
          acc
        end
      end)

    final_transfers = Map.values(transfers)

    final_transfers ++ nft_transfers
  end

  def aggregate_token_burnings(token_transfers) do
    {transfers, nft_transfers} =
      token_transfers
      |> Enum.reduce({%{}, []}, fn token_transfer, acc ->
        if token_transfer.to_address_hash == @burn_address_hash do
          aggregate_reducer(token_transfer, acc)
        else
          acc
        end
      end)

    final_transfers = Map.values(transfers)

    final_transfers ++ nft_transfers
  end

  defp aggregate_reducer(%{amount: amount} = token_transfer, {acc1, acc2}) when is_nil(amount) do
    new_entry = %{
      token: token_transfer.token,
      amount: nil,
      token_id: token_transfer.token_id,
      to_address_hash: token_transfer.to_address_hash,
      from_address_hash: token_transfer.from_address_hash
    }

    {acc1, [new_entry | acc2]}
  end

  defp aggregate_reducer(token_transfer, {acc1, acc2}) do
    new_entry = %{
      token: token_transfer.token,
      amount: token_transfer.amount,
      token_id: token_transfer.token_id,
      to_address_hash: token_transfer.to_address_hash,
      from_address_hash: token_transfer.from_address_hash
    }

    existing_entry = Map.get(acc1, token_transfer.token_contract_address, %{new_entry | amount: Decimal.new(0)})

    new_acc1 =
      Map.put(acc1, token_transfer.token_contract_address, %{
        new_entry
        | amount: Decimal.add(new_entry.amount, existing_entry.amount)
      })

    {new_acc1, acc2}
  end

  def token_type_name(type) do
    case type do
      :erc20 -> gettext("ERC-20 ")
      :erc721 -> gettext("ERC-721 ")
      _ -> ""
    end
  end

  def processing_time_duration(%Transaction{block: nil}) do
    :pending
  end

  def processing_time_duration(%Transaction{earliest_processing_start: nil}) do
    avg_time =
      AverageBlockTime.average_block_time()
      |> Duration.to_seconds()

    {:ok, "<= #{avg_time} seconds"}
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

  def empty_exchange_rate?(exchange_rate) do
    Token.null?(exchange_rate)
  end

  def formatted_status(status) do
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
        token_transfer_type = get_token_transfer_type(transaction.token_transfers)

        case token_transfer_type do
          @token_minting_type -> gettext(@token_minting_title)
          @token_burning_type -> gettext(@token_burning_title)
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

  defp tab_name(["token_transfers"]), do: gettext("Token Transfers")
  defp tab_name(["internal_transactions"]), do: gettext("Internal Transactions")
  defp tab_name(["logs"]), do: gettext("Logs")
  defp tab_name(["raw_trace"]), do: gettext("Raw Trace")

  defp get_token_transfer_type(token_transfers) do
    token_transfers
    |> Enum.reduce("", fn token_transfer, type ->
      cond do
        token_transfer.to_address_hash == @burn_address_hash ->
          update_transfer_type_if_burning(type)

        token_transfer.from_address_hash == @burn_address_hash ->
          update_transfer_type_if_minting(type)

        true ->
          @token_transfer_type
      end
    end)
  end

  defp update_transfer_type_if_minting(type) do
    case type do
      "" -> @token_minting_type
      @token_burning_type -> @token_transfer_type
      _ -> type
    end
  end

  defp update_transfer_type_if_burning(type) do
    case type do
      "" -> @token_burning_type
      @token_minting_type -> @token_transfer_type
      _ -> type
    end
  end
end
