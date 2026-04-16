defmodule Indexer.Fetcher.Optimism.SuperchainConfig do
  @moduledoc """
  Loads selected Optimism chain parameters from a Superchain TOML file,
  persists them to the `constants` table, and serves DB-backed values
  with env-based fallback.
  """

  require Logger

  import Ecto.Query

  alias Explorer.Application.Constants
  alias Explorer.Repo

  @holocene_timestamp_key "optimism_l2_holocene_timestamp"
  @isthmus_timestamp_key "optimism_l2_isthmus_timestamp"
  @jovian_timestamp_key "optimism_l2_jovian_timestamp"
  @eip1559_denominator_key "optimism_eip1559_base_fee_max_change_denominator"
  @eip1559_elasticity_key "optimism_eip1559_elasticity_multiplier"
  @system_config_contract_key "optimism_l1_system_config_contract"
  @portal_contract_key "optimism_l1_portal_contract"
  @batch_submitter_key "optimism_l1_batch_submitter"
  @batch_inbox_key "optimism_l1_batch_inbox"
  @batch_start_block_key "optimism_l1_batch_start_block"
  @batch_genesis_l2_block_key "optimism_l2_batch_genesis_block_number"

  @spec refresh() :: :ok
  def refresh do
    toml_values =
      case load_superchain_toml_values() do
        {:ok, values} ->
          values

        {:error, reason} ->
          Logger.warning(
            "Cannot load Superchain TOML config. Falling back to dedicated env vars. Reason: #{inspect(reason)}"
          )

          %{}
      end

    set_integer(
      @holocene_timestamp_key,
      toml_values[{"hardforks", "holocene_time"}],
      holocene_timestamp_l2_fallback()
    )

    set_integer(
      @isthmus_timestamp_key,
      toml_values[{"hardforks", "isthmus_time"}],
      isthmus_timestamp_l2_fallback()
    )

    set_integer(@jovian_timestamp_key, toml_values[{"hardforks", "jovian_time"}], jovian_timestamp_l2_fallback())

    set_integer(
      @eip1559_denominator_key,
      toml_values[{"optimism", "eip1559_denominator"}],
      eip1559_base_fee_max_change_denominator_fallback()
    )

    set_integer(
      @eip1559_elasticity_key,
      toml_values[{"optimism", "eip1559_elasticity"}],
      eip1559_elasticity_multiplier_fallback()
    )

    set_address(
      @system_config_contract_key,
      toml_values[{"addresses", "SystemConfigProxy"}],
      optimism_l1_system_config_contract_fallback()
    )

    set_address(
      @portal_contract_key,
      toml_values[{"addresses", "OptimismPortalProxy"}],
      optimism_l1_portal_contract_fallback()
    )

    set_address(
      @batch_submitter_key,
      toml_values[{"genesis.system_config", "batcherAddress"}],
      optimism_l1_batch_submitter_fallback()
    )

    set_address(
      @batch_inbox_key,
      toml_values[{"genesis.system_config", "batch_inbox_addr"}] || toml_values[{nil, "batch_inbox_addr"}],
      optimism_l1_batch_inbox_fallback()
    )

    set_integer(
      @batch_start_block_key,
      toml_values[{"genesis.l1", "number"}],
      optimism_l1_batch_start_block_fallback()
    )

    set_integer(
      @batch_genesis_l2_block_key,
      toml_values[{"genesis.l2", "number"}],
      optimism_l2_batch_genesis_block_number_fallback()
    )

    :ok
  end

  @spec holocene_timestamp_l2() :: non_neg_integer() | nil
  def holocene_timestamp_l2 do
    get_integer(@holocene_timestamp_key, holocene_timestamp_l2_fallback())
  end

  @spec isthmus_timestamp_l2() :: non_neg_integer() | nil
  def isthmus_timestamp_l2 do
    get_integer(@isthmus_timestamp_key, isthmus_timestamp_l2_fallback())
  end

  @spec jovian_timestamp_l2() :: non_neg_integer() | nil
  def jovian_timestamp_l2 do
    get_integer(@jovian_timestamp_key, jovian_timestamp_l2_fallback())
  end

  @spec eip1559_base_fee_max_change_denominator() :: non_neg_integer()
  def eip1559_base_fee_max_change_denominator do
    get_integer(@eip1559_denominator_key, eip1559_base_fee_max_change_denominator_fallback())
  end

  @spec eip1559_elasticity_multiplier() :: non_neg_integer()
  def eip1559_elasticity_multiplier do
    get_integer(@eip1559_elasticity_key, eip1559_elasticity_multiplier_fallback())
  end

  @spec optimism_l1_system_config_contract() :: String.t() | nil
  def optimism_l1_system_config_contract do
    get_address(@system_config_contract_key, optimism_l1_system_config_contract_fallback())
  end

  @spec optimism_l1_portal_contract() :: String.t() | nil
  def optimism_l1_portal_contract do
    get_address(@portal_contract_key, optimism_l1_portal_contract_fallback())
  end

  @spec optimism_l1_batch_submitter() :: String.t() | nil
  def optimism_l1_batch_submitter do
    get_address(@batch_submitter_key, optimism_l1_batch_submitter_fallback())
  end

  @spec optimism_l1_batch_start_block() :: non_neg_integer() | nil
  def optimism_l1_batch_start_block do
    get_integer(@batch_start_block_key, optimism_l1_batch_start_block_fallback())
  end

  @spec optimism_l1_batch_inbox() :: String.t() | nil
  def optimism_l1_batch_inbox do
    get_address(@batch_inbox_key, optimism_l1_batch_inbox_fallback())
  end

  @spec optimism_l2_batch_genesis_block_number() :: non_neg_integer() | nil
  def optimism_l2_batch_genesis_block_number do
    get_integer(@batch_genesis_l2_block_key, optimism_l2_batch_genesis_block_number_fallback())
  end

  @spec eip1559_constants() :: {non_neg_integer(), non_neg_integer()}
  def eip1559_constants do
    {eip1559_base_fee_max_change_denominator(), eip1559_elasticity_multiplier()}
  end

  defp load_superchain_toml_values do
    case superchain_config_file_path() do
      nil ->
        {:error, :superchain_config_file_path_not_set}

      file_path ->
        with {:ok, content} <- read_superchain_file(file_path) do
          parse_toml(content)
        end
    end
  end

  defp superchain_config_file_path do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism, [])[:superchain_config_file_path]
    |> blank_to_nil()
  end

  defp read_superchain_file(file_path) do
    if String.starts_with?(file_path, ["http://", "https://"]) do
      read_remote_superchain_file(file_path)
    else
      File.read(file_path)
    end
  end

  defp read_remote_superchain_file(url) do
    request_url = normalize_github_blob_url(url)
    http_options = [autoredirect: true, timeout: 15_000, connect_timeout: 5_000]

    :inets.start()
    :ssl.start()

    case :httpc.request(:get, {String.to_charlist(request_url), []}, http_options, body_format: :binary) do
      {:ok, {{_http_version, 200, _status_text}, _headers, body}} ->
        {:ok, body}

      {:ok, {{_http_version, status, _status_text}, _headers, _body}} ->
        {:error, {:http_error, status, request_url}}

      {:error, reason} ->
        {:error, {:http_request_failed, reason, request_url}}
    end
  end

  defp normalize_github_blob_url(url) do
    Regex.replace(
      ~r/^https:\/\/github\.com\/([^\/]+)\/([^\/]+)\/blob\/([^\/]+)\/(.+)$/,
      url,
      "https://raw.githubusercontent.com/\\1/\\2/\\3/\\4"
    )
  end

  defp parse_toml(content) do
    values =
      content
      |> String.split("\n")
      |> Enum.reduce({nil, %{}}, fn line, {section, acc} ->
        cleaned_line = clean_toml_line(line)

        cond do
          cleaned_line == "" ->
            {section, acc}

          String.starts_with?(cleaned_line, "[") and String.ends_with?(cleaned_line, "]") ->
            new_section =
              cleaned_line
              |> String.trim_leading("[")
              |> String.trim_trailing("]")

            {new_section, acc}

          String.contains?(cleaned_line, "=") ->
            [raw_key, raw_value] = String.split(cleaned_line, "=", parts: 2)
            key = String.trim(raw_key)
            parsed_value = parse_toml_value(raw_value)
            {section, Map.put(acc, {section, key}, parsed_value)}

          true ->
            {section, acc}
        end
      end)
      |> elem(1)

    {:ok, values}
  rescue
    error -> {:error, {:toml_parse_failed, error}}
  end

  defp clean_toml_line(line) do
    line
    |> strip_toml_comment()
    |> String.trim()
  end

  # Removes a TOML line comment (everything from the first '#' that is outside
  # a quoted string), handling escaped backslashes and quotes inside strings.
  defp strip_toml_comment(line) do
    strip_toml_comment(line, _in_quote = false, _acc = [])
  end

  defp strip_toml_comment(<<>>, _in_quote, acc), do: IO.iodata_to_binary(Enum.reverse(acc))
  defp strip_toml_comment(<<?#, _rest::binary>>, false, acc), do: IO.iodata_to_binary(Enum.reverse(acc))

  defp strip_toml_comment(<<?\\, ?\\, rest::binary>>, true, acc),
    do: strip_toml_comment(rest, true, [?\\, ?\\ | acc])

  defp strip_toml_comment(<<?\\, ?", rest::binary>>, true, acc),
    do: strip_toml_comment(rest, true, [?", ?\\ | acc])

  defp strip_toml_comment(<<?", rest::binary>>, in_quote, acc),
    do: strip_toml_comment(rest, !in_quote, [?" | acc])

  defp strip_toml_comment(<<char, rest::binary>>, in_quote, acc),
    do: strip_toml_comment(rest, in_quote, [char | acc])

  defp parse_toml_value(raw_value) do
    value = String.trim(raw_value)

    if String.starts_with?(value, "\"") and String.ends_with?(value, "\"") do
      value
      |> String.trim_leading("\"")
      |> String.trim_trailing("\"")
    else
      case Integer.parse(value) do
        {integer, ""} -> integer
        _ -> value
      end
    end
  end

  defp set_integer(key, value_from_toml, fallback_value) do
    value =
      cond do
        is_integer(value_from_toml) -> value_from_toml
        is_integer(fallback_value) -> fallback_value
        true -> nil
      end

    case value do
      integer when is_integer(integer) -> Constants.set_constant_value(key, Integer.to_string(integer))
      _ -> clear_constant_value(key)
    end
  end

  defp set_address(key, value_from_toml, fallback_value) do
    value =
      cond do
        address?(value_from_toml) -> String.downcase(value_from_toml)
        address?(fallback_value) -> String.downcase(fallback_value)
        true -> nil
      end

    case value do
      address when is_binary(address) -> Constants.set_constant_value(key, address)
      _ -> clear_constant_value(key)
    end
  end

  defp clear_constant_value(key) do
    from(c in Constants, where: c.key == ^key)
    |> Repo.delete_all()

    :ok
  end

  defp get_integer(key, fallback) do
    key
    |> Constants.get_constant_value()
    |> parse_integer_or_nil()
    |> case do
      nil -> fallback
      integer -> integer
    end
  end

  defp get_address(key, fallback) do
    case Constants.get_constant_value(key) do
      nil ->
        normalize_fallback_address(fallback)

      value ->
        if address?(value), do: String.downcase(value), else: normalize_fallback_address(fallback)
    end
  end

  defp normalize_fallback_address(fallback) when is_binary(fallback) do
    if address?(fallback), do: String.downcase(fallback), else: nil
  end

  defp normalize_fallback_address(_), do: nil

  defp parse_integer_or_nil(nil), do: nil

  defp parse_integer_or_nil(value) when is_binary(value) do
    case Integer.parse(value) do
      {integer, ""} when integer >= 0 -> integer
      _ -> nil
    end
  end

  defp blank_to_nil(nil), do: nil

  defp blank_to_nil(value) when is_binary(value) do
    value
    |> String.trim()
    |> case do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp address?(value) when is_binary(value) do
    Regex.match?(~r/^0x[0-9a-fA-F]{40}$/, value)
  end

  defp address?(_), do: false

  defp holocene_timestamp_l2_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism.EIP1559ConfigUpdate, [])[:holocene_timestamp_l2]
  end

  defp isthmus_timestamp_l2_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism, [])[:isthmus_timestamp_l2]
  end

  defp jovian_timestamp_l2_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism.EIP1559ConfigUpdate, [])[:jovian_timestamp_l2]
  end

  defp eip1559_base_fee_max_change_denominator_fallback do
    Application.get_env(:explorer, :base_fee_max_change_denominator)
  end

  defp eip1559_elasticity_multiplier_fallback do
    Application.get_env(:explorer, :elasticity_multiplier)
  end

  defp optimism_l1_system_config_contract_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism, [])[:optimism_l1_system_config]
  end

  defp optimism_l1_portal_contract_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism, [])[:portal]
  end

  defp optimism_l1_batch_submitter_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism.TransactionBatch, [])[:submitter]
  end

  defp optimism_l1_batch_inbox_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism.TransactionBatch, [])[:inbox]
  end

  defp optimism_l1_batch_start_block_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism, [])[:start_block_l1]
  end

  defp optimism_l2_batch_genesis_block_number_fallback do
    Application.get_env(:indexer, Indexer.Fetcher.Optimism.TransactionBatch, [])[:genesis_block_l2]
  end
end
