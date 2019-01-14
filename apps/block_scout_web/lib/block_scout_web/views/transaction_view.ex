defmodule BlockScoutWeb.TransactionView do
  use BlockScoutWeb, :view

  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.Block.Reward
  alias Explorer.Chain.{Address, Block, InternalTransaction, Transaction, Wei}
  alias BlockScoutWeb.{AddressView, BlockView, TabHelpers}

  import BlockScoutWeb.Gettext

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

  def formatted_status(transaction) do
    transaction
    |> Chain.transaction_to_status()
    |> case do
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

  def should_decode?(transaction) do
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
end
