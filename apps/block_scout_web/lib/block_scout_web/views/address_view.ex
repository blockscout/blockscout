defmodule BlockScoutWeb.AddressView do
  use BlockScoutWeb, :view

  alias Explorer.Chain
  alias Explorer.Chain.{Address, Hash, InternalTransaction, SmartContract, Token, TokenTransfer, Transaction, Wei}

  @dialyzer :no_match

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

  def balance_percentage(%Address{fetched_coin_balance: balance}) do
    balance
    |> Wei.to(:ether)
    |> Decimal.div(Decimal.new(Chain.total_supply()))
    |> Decimal.mult(100)
    |> Decimal.round(4)
    |> Decimal.to_string(:normal)
    |> Kernel.<>("% #{gettext("Market Cap")}")
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

  def qr_code(%Address{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def render_partial(%{partial: partial, address: address, contract: contract?, truncate: truncate}) do
    render(
      partial,
      address: address,
      contract: contract?,
      truncate: truncate
    )
  end

  def render_partial(text), do: text

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

  def transaction_count(%Address{} = address) do
    Chain.address_to_transactions_estimated_count(address)
  end

  def trimmed_hash(%Hash{} = hash) do
    string_hash = to_string(hash)
    "#{String.slice(string_hash, 0..5)}–#{String.slice(string_hash, -6..-1)}"
  end

  def trimmed_hash(_), do: ""

  defp matching_address_check(%Address{hash: hash} = current_address, %Address{hash: hash}, contract?, truncate) do
    %{
      partial: "_responsive_hash.html",
      address: current_address,
      contract: contract?,
      truncate: truncate
    }
  end

  defp matching_address_check(_current_address, %Address{} = address, contract?, truncate) do
    %{
      partial: "_link.html",
      address: address,
      contract: contract?,
      truncate: truncate
    }
  end
end
