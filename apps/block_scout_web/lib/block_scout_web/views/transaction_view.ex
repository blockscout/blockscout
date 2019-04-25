defmodule BlockScoutWeb.TransactionView do
  use BlockScoutWeb, :view

  alias ABI.TypeDecoder
  alias BlockScoutWeb.{AddressView, BlockView, TabHelpers}
  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.{Address, Block, InternalTransaction, TokenTransfer, Transaction, Wei}
  alias Explorer.ExchangeRates.Token
  alias Timex.Duration

  import BlockScoutWeb.Gettext
  import BlockScoutWeb.Tokens.Helpers

  @tabs ["token_transfers", "internal_transactions", "logs"]

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

  def erc20_token_transfer(
        %Transaction{
          status: :ok,
          created_contract_address_hash: nil,
          input: input,
          value: value
        },
        token_transfers
      ) do
    zero_wei = %Wei{value: Decimal.new(0)}

    case {to_string(input), value} do
      {unquote(TokenTransfer.transfer_function_signature()) <> params, ^zero_wei} ->
        types = [:address, {:uint, 256}]

        [address, value] = decode_params(params, types)

        decimal_value = Decimal.new(value)

        Enum.find(token_transfers, fn token_transfer ->
          token_transfer.to_address_hash.bytes == address && token_transfer.amount == decimal_value
        end)

      _ ->
        nil
    end
  rescue
    _ -> nil
  end

  def erc20_token_transfer(_, _) do
    nil
  end

  def erc721_token_transfer(
        %Transaction{
          status: :ok,
          created_contract_address_hash: nil,
          input: input,
          value: value
        },
        token_transfers
      ) do
    zero_wei = %Wei{value: Decimal.new(0)}

    # https://github.com/OpenZeppelin/openzeppelin-solidity/blob/master/contracts/token/ERC721/ERC721.sol#L35
    {from_address, to_address} =
      case {to_string(input), value} do
        # transferFrom(address,address,uint256)
        {"0x23b872dd" <> params, ^zero_wei} ->
          types = [:address, :address, {:uint, 256}]
          [from_address, to_address, _value] = decode_params(params, types)
          {from_address, to_address}

        # safeTransferFrom(address,address,uint256)
        {"0x42842e0e" <> params, ^zero_wei} ->
          types = [:address, :address, {:uint, 256}]
          [from_address, to_address, _value] = decode_params(params, types)
          {from_address, to_address}

        # safeTransferFrom(address,address,uint256,bytes)
        {"0xb88d4fde" <> params, ^zero_wei} ->
          types = [:address, :address, {:uint, 256}, :bytes]
          [from_address, to_address, _value, _data] = decode_params(params, types)
          {from_address, to_address}

        _ ->
          nil
      end

    Enum.find(token_transfers, fn token_transfer ->
      token_transfer.from_address_hash.bytes == from_address && token_transfer.to_address_hash.bytes == to_address
    end)
  rescue
    _ -> nil
  end

  def erc721_token_transfer(_, _), do: nil

  def processing_time_duration(%Transaction{block: nil}) do
    :pending
  end

  def processing_time_duration(%Transaction{earliest_processing_start: nil}) do
    :unknown
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
      nil ->
        0

      %Block{consensus: true} ->
        {:ok, confirmations} = Chain.confirmations(block, named_arguments)
        Cldr.Number.to_string!(confirmations, format: "#,###")
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
    Cldr.Number.to_string!(gas)
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
      involves_token_transfers?(transaction) -> gettext("Token Transfer")
      contract_creation?(transaction) -> gettext("Contract Creation")
      involves_contract?(transaction) -> gettext("Contract Call")
      true -> gettext("Transaction")
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

  defp decode_params(params, types) do
    params
    |> Base.decode16!(case: :mixed)
    |> TypeDecoder.decode_raw(types)
  end
end
