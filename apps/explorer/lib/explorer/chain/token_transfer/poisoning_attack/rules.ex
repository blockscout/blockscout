# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Rules do
  @moduledoc """
  The weighted rules that score a token transfer as an address poisoning
  attack. Pure: everything the rules look at comes in the
  `Explorer.Chain.TokenTransfer.PoisoningAttack.Context`.

  | Rule | Weight | Fires when |
  |---|---|---|
  | `zero_amount` | 0 | a fungible transfer carries no value |
  | `sender_mismatch` | 0 | the transaction sender is not the transfer sender |
  | `suspicious_outgoing` | 2 | the victim is the transfer sender and the transaction sender is neither participant |
  | `initiator_fanout` | 1 | the transaction sender touched many distinct addresses within the batch |
  | `dust_from_counterparty` | 1 | the counterparty sent a positive amount below the dust threshold of the token |
  | `scam_flag` | 3 | the token contract, the counterparty or the transaction sender carries a scam badge |
  | `lookalike_recipient` | 5 | the counterparty is unseen and resembles a previous recipient of the victim |
  | `name_imitation` | 2 (+1 unverified) | the token imitates the name or symbol of a known asset from another contract |

  `zero_amount` and `sender_mismatch` carry no weight: they are the candidate
  trigger that decides whether the costly `lookalike_recipient` lookup is worth
  running (see `candidate?/2`), not evidence by themselves.

  A mint or burn is never scored, and a transfer explained by an attributed
  flow — a verified, named or tagged contract, a Safe, an EIP-7702 account, an
  address the operator listed — keeps its `sender_mismatch`,
  `suspicious_outgoing` and `initiator_fanout` signals suppressed. The other
  rules still apply: an attributed router can still carry a scam token.
  """

  alias Explorer.Chain.{Hash, Token, TokenTransfer}
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{Config, Context, Result}

  @weights %{
    zero_amount: 0,
    sender_mismatch: 0,
    suspicious_outgoing: 2,
    initiator_fanout: 1,
    dust_from_counterparty: 1,
    scam_flag: 3,
    lookalike_recipient: 5,
    name_imitation: 2
  }

  @explained_by_attribution [:sender_mismatch, :suspicious_outgoing, :initiator_fanout]

  @typedoc "A rule that fired: its name, its weight and what it matched."
  @type signal :: {atom(), non_neg_integer(), map()}

  @doc """
  The victim / counterparty pairs a transfer is scored for, decided by who
  sent the transaction:

  * the transfer sender did — only the recipient can be the victim (a dust or
    zero transfer landing in their history);
  * the transfer recipient did — only the sender can be the victim (an operator
    pulling from them);
  * someone else, or nobody known, did — either side may be the victim: a fake
    outgoing transfer is emitted *from* the victim, a fake incoming one *to*
    them.

  A self-transfer has no counterparty and is never scored.
  """
  @spec orientations(TokenTransfer.t(), Hash.Address.t() | nil) :: [{Hash.Address.t(), Hash.Address.t()}]
  def orientations(%TokenTransfer{from_address_hash: same, to_address_hash: same}, _issuer), do: []

  def orientations(%TokenTransfer{from_address_hash: from, to_address_hash: to}, issuer) do
    cond do
      issuer == from -> [{to, from}]
      issuer == to -> [{from, to}]
      true -> [{from, to}, {to, from}]
    end
  end

  @doc """
  Whether the transfer is a candidate worth the look-alike lookup: a trigger
  signal that survived suppression, or positive dust from the counterparty.
  """
  @spec candidate?(Context.t(), Config.t()) :: boolean()
  def candidate?(%Context{transfer_type: type}, _config) when type != :token_transfer, do: false

  def candidate?(%Context{} = context, %Config{} = config) do
    suppressed? = attributed_flow?(context, config)

    Enum.any?([zero_amount(context), sender_mismatch(context), dust_from_counterparty(context, config)], fn
      nil -> false
      {rule, _weight, _details} -> not (suppressed? and rule in @explained_by_attribution)
    end)
  end

  @doc """
  Scores the transfer of the context from the point of view of its victim.
  """
  @spec evaluate(Context.t(), Config.t()) :: Result.t()
  def evaluate(%Context{transfer_type: type} = context, _config) when type != :token_transfer do
    %Result{
      token_transfer: context.token_transfer,
      victim: context.victim,
      mimic: context.counterparty,
      issuer: context.issuer,
      suppressed: [Atom.to_string(type)]
    }
  end

  def evaluate(%Context{} = context, %Config{} = config) do
    signals =
      [
        zero_amount(context),
        sender_mismatch(context),
        suspicious_outgoing(context),
        initiator_fanout(context, config),
        dust_from_counterparty(context, config),
        scam_flag(context),
        lookalike_recipient(context, config),
        name_imitation(context, config)
      ]
      |> Enum.reject(&is_nil/1)

    {suppressed, fired} =
      if attributed_flow?(context, config) do
        Enum.split_with(signals, fn {rule, _weight, _details} -> rule in @explained_by_attribution end)
      else
        {[], signals}
      end

    fired = Enum.sort_by(fired, fn {_rule, weight, _details} -> weight end, :desc)

    %Result{
      token_transfer: context.token_transfer,
      score: Enum.reduce(fired, 0, fn {_rule, weight, _details}, acc -> acc + weight end),
      rules: Enum.map(fired, fn {rule, _weight, _details} -> Atom.to_string(rule) end),
      details: Map.new(fired, fn {rule, _weight, details} -> {Atom.to_string(rule), details} end),
      suppressed: Enum.map(suppressed, fn {rule, _weight, _details} -> Atom.to_string(rule) end),
      victim: context.victim,
      mimic: context.counterparty,
      issuer: context.issuer
    }
  end

  @doc """
  Whether two distinct addresses share their first `prefix_length` and last
  `suffix_length` hex characters.
  """
  @spec lookalike?(Hash.Address.t(), Hash.Address.t(), non_neg_integer(), non_neg_integer()) :: boolean()
  def lookalike?(%Hash{} = same, %Hash{} = same, _prefix_length, _suffix_length), do: false

  def lookalike?(%Hash{} = a, %Hash{} = b, prefix_length, suffix_length) do
    lookalike_key(a, prefix_length, suffix_length) == lookalike_key(b, prefix_length, suffix_length)
  end

  @doc """
  The `{prefix, suffix}` of the hex representation of an address, the part a
  human compares.
  """
  @spec lookalike_key(Hash.Address.t(), non_neg_integer(), non_neg_integer()) :: {String.t(), String.t()}
  def lookalike_key(%Hash{bytes: bytes}, prefix_length, suffix_length) do
    hex = Base.encode16(bytes, case: :lower)
    size = byte_size(hex)

    {binary_part(hex, 0, min(prefix_length, size)),
     binary_part(hex, size - min(suffix_length, size), min(suffix_length, size))}
  end

  @doc """
  The form in which asset names and symbols are compared: Unicode compatibility
  normalized, lowercased, with format characters and everything that is not a
  letter or a digit dropped. Names shorter than two characters are ignored.

      iex> normalize_asset_name("Tether USD")
      "tetherusd"
      iex> normalize_asset_name("ＵＳＤＴ")
      "usdt"
      iex> normalize_asset_name("$")
      nil
  """
  @spec normalize_asset_name(String.t() | nil) :: String.t() | nil
  def normalize_asset_name(nil), do: nil

  def normalize_asset_name(name) when is_binary(name) do
    normalized =
      name
      |> String.normalize(:nfkc)
      |> String.downcase()
      |> String.replace(~r/[^\p{L}\p{N}]/u, "")

    if String.length(normalized) >= 2, do: normalized, else: nil
  end

  def normalize_asset_name(_), do: nil

  # Signals

  defp zero_amount(%Context{amount: %Decimal{} = amount}) do
    if Decimal.eq?(amount, 0), do: {:zero_amount, @weights.zero_amount, %{}}, else: nil
  end

  defp zero_amount(_context), do: nil

  defp sender_mismatch(%Context{issuer: nil}), do: nil

  defp sender_mismatch(%Context{issuer: issuer, token_transfer: %TokenTransfer{from_address_hash: from}}) do
    if issuer != from, do: {:sender_mismatch, @weights.sender_mismatch, %{}}, else: nil
  end

  defp suspicious_outgoing(%Context{issuer: nil}), do: nil

  defp suspicious_outgoing(%Context{
         issuer: issuer,
         victim: victim,
         token_transfer: %TokenTransfer{from_address_hash: from, to_address_hash: to}
       }) do
    if victim == from and issuer != from and issuer != to do
      {:suspicious_outgoing, @weights.suspicious_outgoing, %{}}
    else
      nil
    end
  end

  defp initiator_fanout(%Context{issuer: nil}, _config), do: nil

  defp initiator_fanout(%Context{fanout: fanout}, %Config{fanout_threshold: threshold}) do
    if fanout >= threshold do
      {:initiator_fanout, @weights.initiator_fanout, %{"distinct_participants" => fanout}}
    else
      nil
    end
  end

  defp dust_from_counterparty(
         %Context{amount: %Decimal{} = amount, counterparty: counterparty, token_transfer: token_transfer} = context,
         config
       ) do
    threshold = dust_threshold(context, config)

    if (token_transfer.from_address_hash == counterparty and threshold) && Decimal.gt?(amount, 0) &&
         Decimal.lt?(amount, threshold) do
      {:dust_from_counterparty, @weights.dust_from_counterparty,
       %{"amount" => Decimal.to_string(amount, :normal), "threshold" => Decimal.to_string(threshold, :normal)}}
    else
      nil
    end
  end

  defp dust_from_counterparty(_context, _config), do: nil

  defp dust_threshold(%Context{token_transfer: token_transfer, token: token}, %Config{} = config) do
    case Map.fetch(config.dust_thresholds, token_transfer.token_contract_address_hash) do
      {:ok, threshold} -> threshold
      :error -> default_dust_threshold(token, config.dust_default_threshold)
    end
  end

  defp default_dust_threshold(%Token{decimals: %Decimal{} = decimals}, %Decimal{} = default) do
    Decimal.mult(default, Decimal.new(1, 1, decimals |> Decimal.to_integer()))
  end

  defp default_dust_threshold(_token, _default), do: nil

  defp scam_flag(%Context{scam_hashes: scam_hashes} = context) do
    flagged =
      [
        {"token_contract", context.token_transfer.token_contract_address_hash},
        {"counterparty", context.counterparty},
        {"issuer", context.issuer}
      ]
      |> Enum.filter(fn {_role, hash} ->
        not is_nil(hash) and hash != context.victim and MapSet.member?(scam_hashes, hash)
      end)
      |> Enum.map(fn {role, _hash} -> role end)

    case flagged do
      [] -> nil
      roles -> {:scam_flag, @weights.scam_flag, %{"participants" => roles}}
    end
  end

  defp lookalike_recipient(%Context{recipients: nil}, _config), do: nil

  defp lookalike_recipient(%Context{recipients: recipients, counterparty: counterparty}, %Config{} = config) do
    key = lookalike_key(counterparty, config.prefix_length, config.suffix_length)

    if MapSet.member?(recipients, counterparty) do
      nil
    else
      recipients
      |> Enum.find(&(lookalike_key(&1, config.prefix_length, config.suffix_length) == key))
      |> case do
        nil ->
          nil

        matched ->
          {prefix, suffix} = key

          {:lookalike_recipient, @weights.lookalike_recipient,
           %{"matched_recipient" => to_string(matched), "prefix" => prefix, "suffix" => suffix}}
      end
    end
  end

  defp name_imitation(%Context{known_assets: nil}, _config), do: nil
  defp name_imitation(%Context{token: nil}, _config), do: nil

  defp name_imitation(%Context{token: %Token{} = token, known_assets: known_assets} = context, %Config{} = config) do
    contract = context.token_transfer.token_contract_address_hash

    [{"symbol", token.symbol, known_assets.symbols}, {"name", token.name, known_assets.names}]
    |> Enum.find_value(fn {field, value, index} ->
      with key when not is_nil(key) <- normalize_asset_name(value),
           accepted when not is_nil(accepted) <- Map.get(index, key),
           false <- MapSet.member?(accepted, contract) do
        {field, value, accepted}
      else
        _ -> nil
      end
    end)
    |> case do
      nil ->
        nil

      {field, value, accepted} ->
        unverified? = not Context.participant(context, contract).verified?
        weight = @weights.name_imitation + if(unverified?, do: config.unverified_token_weight, else: 0)

        {:name_imitation, weight,
         %{
           "matched" => field,
           "value" => value,
           "accepted_contracts" => accepted |> Enum.take(5) |> Enum.map(&to_string/1),
           "unverified" => unverified?
         }}
    end
  end

  # Suppression

  defp attributed_flow?(%Context{} = context, %Config{ignored_addresses: ignored}) do
    [
      context.token_transfer.from_address_hash,
      context.token_transfer.to_address_hash,
      context.issuer,
      context.transaction_to
    ]
    |> Enum.reject(&is_nil/1)
    |> Enum.any?(fn hash -> MapSet.member?(ignored, hash) or Context.participant(context, hash).attributed? end)
  end
end
