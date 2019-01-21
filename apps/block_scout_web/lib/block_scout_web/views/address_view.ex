defmodule BlockScoutWeb.AddressView do
  use BlockScoutWeb, :view

  import BlockScoutWeb.AddressController, only: [validation_count: 1]

  alias BlockScoutWeb.LayoutView
  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, InternalTransaction, SmartContract, Token, TokenTransfer, Transaction, Wei}
  alias Explorer.Chain.Block.Reward

  @dialyzer :no_match

  @tabs [
    "coin_balances",
    "contracts",
    "internal_transactions",
    "read_contract",
    "tokens",
    "transactions",
    "validations"
  ]

  def address_partial_selector(struct_to_render_from, direction, current_address, truncate \\ false)

  def address_partial_selector(%Address{} = address, _, current_address, truncate) do
    matching_address_check(current_address, address, contract?(address), truncate)
  end

  def address_partial_selector(
        %InternalTransaction{to_address_hash: nil, created_contract_address_hash: nil},
        :to,
        _current_address,
        _truncate
      ) do
    gettext("Contract Address Pending")
  end

  def address_partial_selector(
        %InternalTransaction{to_address: nil, created_contract_address: contract_address},
        :to,
        current_address,
        truncate
      ) do
    matching_address_check(current_address, contract_address, true, truncate)
  end

  def address_partial_selector(%InternalTransaction{to_address: address}, :to, current_address, truncate) do
    matching_address_check(current_address, address, contract?(address), truncate)
  end

  def address_partial_selector(%InternalTransaction{from_address: address}, :from, current_address, truncate) do
    matching_address_check(current_address, address, contract?(address), truncate)
  end

  def address_partial_selector(%TokenTransfer{to_address: address}, :to, current_address, truncate) do
    matching_address_check(current_address, address, contract?(address), truncate)
  end

  def address_partial_selector(%TokenTransfer{from_address: address}, :from, current_address, truncate) do
    matching_address_check(current_address, address, contract?(address), truncate)
  end

  def address_partial_selector(
        %Transaction{to_address_hash: nil, created_contract_address_hash: nil},
        :to,
        _current_address,
        _truncate
      ) do
    gettext("Contract Address Pending")
  end

  def address_partial_selector(
        %Transaction{to_address: nil, created_contract_address: contract_address},
        :to,
        current_address,
        truncate
      ) do
    matching_address_check(current_address, contract_address, true, truncate)
  end

  def address_partial_selector(%Transaction{to_address: address}, :to, current_address, truncate) do
    matching_address_check(current_address, address, contract?(address), truncate)
  end

  def address_partial_selector(%Transaction{from_address: address}, :from, current_address, truncate) do
    matching_address_check(current_address, address, contract?(address), truncate)
  end

  def address_partial_selector(%Reward{address: address}, _, current_address, truncate) do
    matching_address_check(current_address, address, false, truncate)
  end

  def address_title(%Address{} = address) do
    if contract?(address) do
      gettext("Contract Address")
    else
      gettext("Address")
    end
  end

  @doc """
  Returns a formatted address balance and includes the unit.
  """
  def balance(%Address{fetched_coin_balance: nil}), do: ""

  def balance(%Address{fetched_coin_balance: balance}) do
    format_wei_value(balance, :ether)
  end

  def balance_percentage(%Address{fetched_coin_balance: balance}, total_supply) do
    balance
    |> Wei.to(:ether)
    |> Decimal.div(Decimal.new(total_supply))
    |> Decimal.mult(100)
    |> Decimal.round(4)
    |> Decimal.to_string(:normal)
    |> Kernel.<>("% #{gettext("Market Cap")}")
  end

  def balance_percentage(%Address{fetched_coin_balance: _} = address) do
    balance_percentage(address, Chain.total_supply())
  end

  def balance_block_number(%Address{fetched_coin_balance_block_number: nil}), do: ""

  def balance_block_number(%Address{fetched_coin_balance_block_number: fetched_coin_balance_block_number}) do
    to_string(fetched_coin_balance_block_number)
  end

  def contract?(%Address{contract_code: nil}), do: false

  def contract?(%Address{contract_code: _}), do: true

  def contract?(nil), do: true

  def validator?(val) when val > 0, do: true

  def validator?(_), do: false

  def hash(%Address{hash: hash}) do
    to_string(hash)
  end

  @doc """
  Returns the primary name of an address if available.
  """
  def primary_name(%Address{names: [_ | _] = address_names}) do
    case Enum.find(address_names, &(&1.primary == true)) do
      nil -> nil
      %Address.Name{name: name} -> name
    end
  end

  def primary_name(%Address{names: _}), do: nil

  def primary_validator_metadata(%Address{names: [_ | _] = address_names}) do
    case Enum.find(address_names, &(&1.primary == true)) do
      %Address.Name{
        metadata:
          metadata = %{
            "license_id" => _,
            "address" => _,
            "state" => _,
            "zipcode" => _,
            "expiration_date" => _,
            "created_date" => _
          }
      } ->
        metadata

      _ ->
        nil
    end
  end

  def primary_validator_metadata(%Address{names: _}), do: nil

  def format_datetime_string(unix_date) do
    unix_date
    |> DateTime.from_unix!()
    |> Timex.format!("{M}-{D}-{YYYY}")
  end

  def qr_code(%Address{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def smart_contract_verified?(%Address{smart_contract: %SmartContract{}}), do: true

  def smart_contract_verified?(%Address{smart_contract: nil}), do: false

  def smart_contract_with_read_only_functions?(%Address{smart_contract: %SmartContract{}} = address) do
    Enum.any?(address.smart_contract.abi, & &1["constant"])
  end

  def smart_contract_with_read_only_functions?(%Address{smart_contract: nil}), do: false

  def token_title(%Token{name: nil, contract_address_hash: contract_address_hash}) do
    contract_address_hash
    |> to_string
    |> String.slice(0..5)
  end

  def token_title(%Token{name: name, symbol: symbol}), do: "#{name} (#{symbol})"

  def trimmed_hash(%Hash{} = hash) do
    string_hash = to_string(hash)
    "#{String.slice(string_hash, 0..5)}–#{String.slice(string_hash, -6..-1)}"
  end

  def transaction_hash(%Address{contracts_creation_internal_transaction: %InternalTransaction{}} = address) do
    address.contracts_creation_internal_transaction.transaction_hash
  end

  def transaction_hash(%Address{contracts_creation_transaction: %Transaction{}} = address) do
    address.contracts_creation_transaction.hash
  end

  def from_address_hash(%Address{contracts_creation_internal_transaction: %InternalTransaction{}} = address) do
    address.contracts_creation_internal_transaction.from_address_hash
  end

  def from_address_hash(%Address{contracts_creation_transaction: %Transaction{}} = address) do
    address.contracts_creation_transaction.from_address_hash
  end

  def trimmed_hash(_), do: ""

  defp matching_address_check(%Address{hash: hash} = current_address, %Address{hash: hash}, contract?, truncate) do
    [
      view_module: __MODULE__,
      partial: "_responsive_hash.html",
      address: current_address,
      contract: contract?,
      truncate: truncate
    ]
  end

  defp matching_address_check(_current_address, %Address{} = address, contract?, truncate) do
    [
      view_module: __MODULE__,
      partial: "_link.html",
      address: address,
      contract: contract?,
      truncate: truncate
    ]
  end

  @doc """
  Get the current tab name/title from the request path and possible tab names.

  The tabs on mobile are represented by a dropdown list, which has a title. This title is the
  currently selected tab name. This function returns that name, properly gettext'ed.

  The list of possible tab names for this page is represented by the attribute @tab.

  Raises error if there is no match, so a developer of a new tab must include it in the list.
  """
  def current_tab_name(request_path) do
    @tabs
    |> Enum.filter(&tab_active?(&1, request_path))
    |> tab_name()
  end

  defp tab_name(["tokens"]), do: gettext("Tokens")
  defp tab_name(["transactions"]), do: gettext("Transactions")
  defp tab_name(["internal_transactions"]), do: gettext("Internal Transactions")
  defp tab_name(["contracts"]), do: gettext("Code")
  defp tab_name(["read_contract"]), do: gettext("Read Contract")
  defp tab_name(["coin_balances"]), do: gettext("Coin Balance History")
  defp tab_name(["validations"]), do: gettext("Blocks Validated")

  def short_hash(%Address{hash: hash}) do
    <<
      "0x",
      short_address::binary-size(6),
      _rest::binary
    >> = to_string(hash)

    "0x" <> short_address
  end

  def address_page_title(address) do
    cond do
      smart_contract_verified?(address) -> "#{address.smart_contract.name} (#{to_string(address)})"
      contract?(address) -> "Contract #{to_string(address)}"
      true -> "#{to_string(address)}"
    end
  end
end
