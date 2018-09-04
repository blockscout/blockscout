defmodule BlockScoutWeb.AddressView do
  use BlockScoutWeb, :view

  alias Explorer.Chain.{Address, Hash, SmartContract}

  @dialyzer :no_match

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

  def balance_block_number(%Address{fetched_coin_balance_block_number: nil}), do: ""

  def balance_block_number(%Address{fetched_coin_balance_block_number: fetched_coin_balance_block_number}) do
    to_string(fetched_coin_balance_block_number)
  end

  def contract?(%Address{contract_code: nil}), do: false

  def contract?(%Address{contract_code: _}), do: true

  def contract?(nil), do: true

  def hash(%Address{hash: hash}) do
    to_string(hash)
  end

  def qr_code(%Address{hash: hash}) do
    hash
    |> to_string()
    |> QRCode.to_png()
    |> Base.encode64()
  end

  def smart_contract_verified?(%Address{smart_contract: %SmartContract{}}), do: true

  def smart_contract_verified?(%Address{smart_contract: nil}), do: false

  def trimmed_hash(%Hash{} = hash) do
    string_hash = to_string(hash)
    "#{String.slice(string_hash, 0..5)}–#{String.slice(string_hash, -6..-1)}"
  end

  def trimmed_hash(_), do: ""

  def smart_contract_with_read_only_functions?(%Address{smart_contract: %SmartContract{}} = address) do
    Enum.any?(address.smart_contract.abi, & &1["constant"])
  end

  def smart_contract_with_read_only_functions?(%Address{smart_contract: nil}), do: false

  def display_address_hash(current_address, target_address, locale, truncate \\ false)

  def display_address_hash(nil, target_address, locale, truncate) do
    render(
      "_link.html",
      address_hash: target_address.hash,
      contract: contract?(target_address),
      locale: locale,
      truncate: truncate
    )
  end

  def display_address_hash(current_address, target_address, locale, truncate) do
    if current_address.hash == target_address.hash do
      render(
        "_responsive_hash.html",
        address_hash: current_address.hash,
        contract: contract?(current_address),
        locale: locale,
        truncate: truncate
      )
    else
      render(
        "_link.html",
        address_hash: target_address.hash,
        contract: contract?(target_address),
        locale: locale,
        truncate: truncate
      )
    end
  end
end
