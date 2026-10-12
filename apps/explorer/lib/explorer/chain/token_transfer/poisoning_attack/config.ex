# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Explorer.Chain.TokenTransfer.PoisoningAttack.Config do
  @moduledoc """
  Settings of the poisoning attack detection, read once per batch from the
  `:explorer, Explorer.Chain.TokenTransfer.PoisoningAttack` application
  environment and parsed into the shapes the rules compare against.

  Everything the environment carries as strings — address hashes, raw token
  amounts, asset names — is cast here so that `PoisoningAttack.Rules` never
  parses anything.
  """

  alias Explorer.Chain.Hash
  alias Explorer.Chain.TokenTransfer.PoisoningAttack
  alias Explorer.Chain.TokenTransfer.PoisoningAttack.{LocalReporter, Rules}

  @default_token_types ["ERC-20", "ERC-8056"]

  @typedoc """
  * `score_threshold` — score from which a transfer counts as an attack.
  * `store_min_score` — score from which a verdict is persisted; defaults to
    `score_threshold`.
  * `prefix_length` / `suffix_length` — number of leading / trailing hex
    characters two addresses must share to count as look-alikes.
  * `recipients_limit` — how many of the victim's latest token transfers and
    transactions are scanned for previous recipients.
  * `fanout_threshold` — distinct participants one transaction sender must touch
    within an import batch to count as a mass sender.
  * `dust_thresholds` — raw amount per token contract under which a positive
    transfer counts as dust.
  * `dust_default_threshold` — dust threshold in whole token units for tokens
    without a specific one; applied through the token's decimals.
  * `unverified_token_weight` — extra weight of a name imitation when the token
    contract is not verified.
  * `token_types` — token types the detection applies to.
  * `ignored_addresses` — addresses whose flows never raise sender mismatch
    signals (routers, bridges, pools, system contracts).
  * `known_assets_override` — accepted contracts per asset name or symbol, in
    addition to the ones derived from the database.
  * `recipients_cache_ttl` — how long a victim's recipients set is kept.
  * `known_assets_update_interval` — how often the known assets index is
    rebuilt.
  * `actions_enabled` — whether identified attacks are reported at all.
  * `reporter` — the `Explorer.Chain.TokenTransfer.PoisoningAttack.Reporter`
    identified attacks go to.
  """
  @type t :: %__MODULE__{
          score_threshold: pos_integer(),
          store_min_score: pos_integer(),
          prefix_length: non_neg_integer(),
          suffix_length: non_neg_integer(),
          recipients_limit: pos_integer(),
          fanout_threshold: pos_integer(),
          dust_thresholds: %{Hash.Address.t() => Decimal.t()},
          dust_default_threshold: Decimal.t() | nil,
          unverified_token_weight: non_neg_integer(),
          token_types: [String.t()],
          ignored_addresses: MapSet.t(Hash.Address.t()),
          known_assets_override: %{String.t() => MapSet.t(Hash.Address.t())},
          recipients_cache_ttl: pos_integer(),
          known_assets_update_interval: pos_integer(),
          actions_enabled: boolean(),
          reporter: module()
        }

  defstruct score_threshold: 5,
            store_min_score: 5,
            prefix_length: 4,
            suffix_length: 4,
            recipients_limit: 200,
            fanout_threshold: 10,
            dust_thresholds: %{},
            dust_default_threshold: Decimal.new("0.01"),
            unverified_token_weight: 1,
            token_types: @default_token_types,
            ignored_addresses: MapSet.new(),
            known_assets_override: %{},
            recipients_cache_ttl: :timer.minutes(10),
            known_assets_update_interval: :timer.hours(1),
            actions_enabled: true,
            reporter: LocalReporter

  @doc """
  Builds the config from the application environment, falling back to the
  struct defaults for anything that is not set.
  """
  @spec load() :: t()
  def load do
    env = Application.get_env(:explorer, PoisoningAttack, [])

    score_threshold = integer(env[:score_threshold], 5)

    %__MODULE__{
      score_threshold: score_threshold,
      store_min_score: integer(env[:store_min_score], score_threshold),
      prefix_length: integer(env[:prefix_length], 4),
      suffix_length: integer(env[:suffix_length], 4),
      recipients_limit: integer(env[:recipients_limit], 200),
      fanout_threshold: integer(env[:fanout_threshold], 10),
      dust_thresholds: dust_thresholds(env[:dust_thresholds]),
      dust_default_threshold: decimal(env[:dust_default_threshold], Decimal.new("0.01")),
      unverified_token_weight: integer(env[:unverified_token_weight], 1),
      token_types: token_types(env[:token_types]),
      ignored_addresses: address_set(env[:ignored_addresses]),
      known_assets_override: known_assets(env[:known_assets_override]),
      recipients_cache_ttl: integer(env[:recipients_cache_ttl], :timer.minutes(10)),
      known_assets_update_interval: integer(env[:known_assets_update_interval], :timer.hours(1)),
      actions_enabled: env[:actions_enabled] != false,
      reporter: reporter(env[:reporter])
    }
  end

  defp reporter(module) when is_atom(module) and not is_nil(module), do: module
  defp reporter(_), do: LocalReporter

  defp integer(value, _default) when is_integer(value), do: value
  defp integer(_value, default), do: default

  defp decimal(nil, default), do: default
  defp decimal(%Decimal{} = value, _default), do: value

  defp decimal(value, default) when is_binary(value) do
    case Decimal.parse(value) do
      {decimal, ""} -> decimal
      _ -> default
    end
  end

  defp decimal(value, _default) when is_integer(value), do: Decimal.new(value)
  defp decimal(_value, default), do: default

  defp dust_thresholds(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {hash_string, threshold}, acc ->
      with {:ok, hash} <- Hash.Address.cast(hash_string),
           %Decimal{} = decimal <- decimal(threshold, nil) do
        Map.put(acc, hash, decimal)
      else
        _ -> acc
      end
    end)
  end

  defp dust_thresholds(_), do: %{}

  defp token_types(types) when is_list(types) and types != [] do
    Enum.map(types, &String.upcase/1)
  end

  defp token_types(_), do: @default_token_types

  defp address_set(hash_strings) when is_list(hash_strings) do
    hash_strings
    |> Enum.flat_map(fn hash_string ->
      case Hash.Address.cast(hash_string) do
        {:ok, hash} -> [hash]
        :error -> []
      end
    end)
    |> MapSet.new()
  end

  defp address_set(_), do: MapSet.new()

  defp known_assets(map) when is_map(map) do
    Enum.reduce(map, %{}, fn {asset, hash_strings}, acc ->
      case Rules.normalize_asset_name(asset) do
        nil -> acc
        key -> Map.update(acc, key, address_set(hash_strings), &MapSet.union(&1, address_set(hash_strings)))
      end
    end)
  end

  defp known_assets(_), do: %{}
end
