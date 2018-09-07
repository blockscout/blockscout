defmodule BlockScoutWeb.TransactionView do
  use BlockScoutWeb, :view

  alias Cldr.Number
  alias Explorer.Chain
  alias Explorer.Chain.{Address, InternalTransaction, Transaction, Wei}
  alias BlockScoutWeb.{AddressView, BlockView}

  import BlockScoutWeb.Gettext

  defguardp is_transaction_type(mod) when mod in [InternalTransaction, Transaction]

  def confirmations(%Transaction{block: block}, named_arguments) when is_list(named_arguments) do
    case block do
      nil -> 0
      _ -> block |> Chain.confirmations(named_arguments) |> Cldr.Number.to_string!(format: "#,###")
    end
  end

  def from_or_to_address?(_token_transfer, nil), do: false

  def from_or_to_address?(%{from_address_hash: from_hash, to_address_hash: to_hash}, %Address{hash: hash}) do
    from_hash == hash || to_hash == hash
  end

  # This is the address to be shown in the to field
  def to_address_hash(%Transaction{to_address_hash: nil, created_contract_address_hash: address_hash}), do: address_hash

  def to_address_hash(%Transaction{to_address: %Address{hash: address_hash}}), do: address_hash

  def fee(%Transaction{} = transaction) do
    {_, value} = Chain.fee(transaction, :wei)
    value
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

  def gas_used(%Transaction{gas_used: nil}), do: gettext("Pending")

  def gas_used(%Transaction{gas_used: gas_used}) do
    Number.to_string!(gas_used)
  end

  def involves_contract?(%Transaction{from_address: from_address, to_address: to_address}) do
    AddressView.contract?(from_address) || AddressView.contract?(to_address)
  end

  def involves_token_transfers?(%Transaction{token_transfers: []}), do: false
  def involves_token_transfers?(%Transaction{token_transfers: transfers}) when is_list(transfers), do: true

  def contract_creation?(%Transaction{to_address: nil}), do: true

  def contract_creation?(_), do: false

  def qr_code(%Transaction{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def format_gas_limit(gas) do
    Number.to_string!(gas)
  end

  def formatted_status(transaction) do
    transaction
    |> Chain.transaction_to_status()
    |> case do
      :failed -> gettext("Failed")
      :out_of_gas -> gettext("Out of Gas")
      :pending -> gettext("Pending")
      :success -> gettext("Success")
    end
  end

  defdelegate formatted_timestamp(block), to: BlockView

  def gas(%type{gas: gas}) when is_transaction_type(type) do
    Cldr.Number.to_string!(gas)
  end

  @doc """
  Converts a transaction's gas price to a displayable value.
  """
  def gas_price(%Transaction{gas_price: gas_price}, unit) when unit in ~w(wei gwei ether)a do
    format_wei_value(gas_price, unit)
  end

  def hash(%Transaction{hash: hash}) do
    to_string(hash)
  end

  def status(transaction) do
    Chain.transaction_to_status(transaction)
  end

  def type_suffix(%Transaction{} = transaction) do
    cond do
      involves_token_transfers?(transaction) -> "token"
      contract_creation?(transaction) -> "contract-creation"
      involves_contract?(transaction) -> "contract-call"
      true -> "transaction"
    end
  end

  def transaction_display_type(%Transaction{} = transaction) do
    cond do
      involves_token_transfers?(transaction) -> gettext("Token Transfer")
      contract_creation?(transaction) -> gettext("Contract Creation")
      involves_contract?(transaction) -> gettext("Contract Call")
      true -> gettext("Transaction")
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

  defp fee_to_denomination({fee_type, fee}, opts) do
    denomination = Keyword.get(opts, :denomination)
    include_label? = Keyword.get(opts, :include_label, true)
    {fee_type, format_wei_value(Wei.from(fee, :wei), denomination, include_unit_label: include_label?)}
  end
end
