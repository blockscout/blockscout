defmodule Explorer.Market.Source.DIA do
  @moduledoc """
  Adapter for fetching exchange rates from https://www.diadata.org/
  """

  require Logger

  alias Explorer.Chain.Hash
  alias Explorer.Market.{Source, Token}

  @behaviour Source

  @impl Source
  def native_coin_fetching_enabled?, do: not is_nil(config(:coin_address_hash))

  @impl Source
  def fetch_native_coin, do: do_fetch_coin(config(:coin_address_hash), "Coin address hash not specified")

  @impl Source
  def secondary_coin_fetching_enabled?, do: not is_nil(config(:secondary_coin_address_hash))

  @impl Source
  def fetch_secondary_coin,
    do: do_fetch_coin(config(:secondary_coin_address_hash), "Secondary coin address hash not specified")

  @impl Source
  def tokens_fetching_enabled?, do: not is_nil(config(:blockchain))

  @impl Source
  def fetch_tokens(state, batch_size) when state in [[], nil] do
    case init_tokens_fetching() do
      {:error, _reason} = error ->
        error

      tokens_to_fetch when is_list(tokens_to_fetch) and tokens_to_fetch !== [] ->
        fetch_tokens(tokens_to_fetch, batch_size)

      _ ->
        {:error, "Tokens not found for configured blockchain: #{config(:blockchain)}"}
    end
  end

  @impl Source
  def fetch_tokens(state, batch_size) do
    # it safe to pattern match here because init_tokens_fetching/0
    # would have returned an error otherwise
    blockchain = config(:blockchain)
    {to_fetch, remaining} = Enum.split(state, batch_size)

    tasks_results =
      to_fetch
      |> Task.async_stream(
        fn token ->
          case Source.http_request(
                 base_url()
                 |> URI.append_path("/assetQuotation")
                 |> URI.append_path("/#{blockchain}")
                 |> URI.append_path("/#{token.contract_address_hash}")
                 |> URI.to_string(),
                 []
               ) do
            {:ok, data} ->
              token_to_import =
                Map.merge(token, %{
                  symbol: data["Symbol"],
                  name: data["Name"],
                  fiat_value: Source.to_decimal(data["Price"]),
                  volume_24h: Source.to_decimal(data["VolumeYesterdayUSD"]),
                  type: "ERC-20"
                })

              {:ok, token_to_import}

            {:error, reason} ->
              {:error, {token, reason}}
          end
        end,
        max_concurrency: 5,
        timeout: :timer.seconds(60),
        zip_input_on_exit: true
      )
      |> Enum.group_by(
        fn
          {:ok, {:ok, _}} -> :ok
          _ -> :error
        end,
        fn
          {:ok, {:ok, token_to_import}} -> token_to_import
          {:ok, {:error, {token, reason}}} -> {token, reason}
          {:error, {token, reason}} -> {token, reason}
        end
      )

    to_import = Map.get(tasks_results, :ok, [])
    tokens_with_errors = Map.get(tasks_results, :error, [])

    remaining_with_errors =
      if Enum.empty?(tokens_with_errors) do
        remaining
      else
        Logger.error("Errors while fetching tokens from DIA: #{inspect(tokens_with_errors)}")
        remaining ++ Enum.map(tokens_with_errors, fn {token, _reason} -> token end)
      end

    if Enum.empty?(to_import) and !Enum.empty?(tokens_with_errors) do
      {:error, tokens_with_errors}
    else
      {:ok, remaining_with_errors, Enum.empty?(remaining_with_errors), to_import}
    end
  end

  @impl Source
  def native_coin_price_history_fetching_enabled?, do: not is_nil(config(:coin_address_hash))

  @impl Source
  def fetch_native_coin_price_history(previous_days), do: do_fetch_coin_price_history(previous_days, false)

  @impl Source
  def secondary_coin_price_history_fetching_enabled?, do: not is_nil(config(:secondary_coin_address_hash))

  @impl Source
  def fetch_secondary_coin_price_history(previous_days), do: do_fetch_coin_price_history(previous_days, true)

  @impl Source
  def market_cap_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_market_cap_history(_previous_days), do: :ignore

  @impl Source
  def tvl_history_fetching_enabled?, do: :ignore

  @impl Source
  def fetch_tvl_history(_previous_days), do: :ignore

  defp do_fetch_coin(coin_address_hash, coin_address_hash_not_specified_error) do
    with {:coin, coin_address_hash} when not is_nil(coin_address_hash) <- {:coin, coin_address_hash},
         {:blockchain, blockchain} when not is_nil(blockchain) <- {:blockchain, config(:blockchain)},
         {:ok, %{"Price" => _price} = data} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/assetQuotation/#{blockchain}/#{coin_address_hash}")
             |> URI.to_string(),
             []
           ) do
      {:ok,
       %Token{
         available_supply: nil,
         total_supply: nil,
         btc_value: nil,
         last_updated: Source.maybe_get_date(data["Time"]),
         market_cap: nil,
         tvl: nil,
         name: data["Name"],
         symbol: data["Symbol"],
         fiat_value: Source.to_decimal(data["Price"]),
         volume_24h: Source.to_decimal(data["VolumeYesterdayUSD"]),
         image_url: nil
       }}
    else
      {:coin, nil} -> {:error, coin_address_hash_not_specified_error}
      {:blockchain, nil} -> {:error, "Blockchain not specified"}
      {:ok, unexpected_response} -> {:error, Source.unexpected_response_error("DIA", unexpected_response)}
      {:error, _reason} = error -> error
    end
  end

  defp init_tokens_fetching do
    with blockchain when not is_nil(blockchain) <- config(:blockchain),
         coin_address_hash = config(:coin_address_hash),
         {:ok, tokens} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/quotedAssets")
             |> URI.append_query("blockchain=#{blockchain}")
             |> URI.to_string(),
             []
           ) do
      tokens
      |> Enum.reduce([], fn
        %{
          "Asset" => %{
            "Address" => token_contract_address_hash_string,
            "Decimals" => decimals
          }
        },
        acc ->
          case (is_nil(coin_address_hash) ||
                  String.downcase(token_contract_address_hash_string) != String.downcase(coin_address_hash)) &&
                 Hash.Address.cast(token_contract_address_hash_string) do
            {:ok, token_contract_address_hash} ->
              token = %{
                contract_address_hash: token_contract_address_hash,
                decimals: decimals
              }

              [token | acc]

            _ ->
              acc
          end

        _, acc ->
          acc
      end)
    else
      nil -> {:error, "Blockchain not specified"}
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_fetch_coin_price_history(previous_days, secondary_coin?) do
    datetime_now = DateTime.utc_now()
    unix_now = datetime_now |> DateTime.to_unix()
    unix_from = unix_now - previous_days * 24 * 60 * 60

    with {:coin, coin_address_hash} when not is_nil(coin_address_hash) <-
           {:coin, if(secondary_coin?, do: config(:secondary_coin_address_hash), else: config(:coin_address_hash))},
         {:blockchain, blockchain} when not is_nil(blockchain) <- {:blockchain, config(:blockchain)},
         {:ok, %{"DataPoints" => [%{"Series" => [%{"values" => values}]}]}} <-
           Source.http_request(
             base_url()
             |> URI.append_path("/assetChartPoints/MA120/#{blockchain}/#{coin_address_hash}")
             |> URI.append_query("starttime=#{unix_from}")
             |> URI.append_query("endtime=#{unix_now}")
             |> URI.to_string(),
             []
           ) do
      values
      |> Enum.reduce_while(%{}, fn value, acc ->
        with time when not is_nil(time) <- List.first(value),
             {:ok, datetime, _} <- DateTime.from_iso8601(time),
             date = DateTime.to_date(datetime),
             price when not is_nil(price) <- List.last(value) do
          {:cont,
           Map.update(
             acc,
             date,
             %{
               closing_price: Source.to_decimal(price),
               date: date,
               opening_price: Source.to_decimal(price),
               secondary_coin: secondary_coin?
             },
             fn existing_entry ->
               %{
                 existing_entry
                 | opening_price: Source.to_decimal(price)
               }
             end
           )}
        else
          _ ->
            {:halt, {:error, "Wrong format of DIA coin price history response: #{inspect(value)}"}}
        end
      end)
      |> case do
        {:error, _reason} = error ->
          error

        price_history_map ->
          {:ok, Map.values(price_history_map)}
      end
    else
      {:coin, nil} -> {:error, "#{Source.secondary_coin_string(secondary_coin?)} address hash not specified"}
      {:blockchain, nil} -> {:error, "Blockchain not specified"}
      {:ok, _} -> {:ok, []}
      {:error, _reason} = error -> error
    end
  end

  defp base_url do
    :base_url |> config() |> URI.parse()
  end

  @spec config(atom()) :: term
  defp config(key) do
    Application.get_env(:explorer, __MODULE__)[key]
  end
end
