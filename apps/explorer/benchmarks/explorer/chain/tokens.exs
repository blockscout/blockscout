defmodule Explorer.Chain.FiatValueBenchmark do
  @moduledoc """
  Benchmark for the performance of fetching fiat value type data from the database.
  """

  use Explorer.BenchmarkCase

  alias Explorer.Repo
  alias Explorer.Chain.Token
  alias Explorer.Market.Fetcher.Token, as: TokenFetcher

  def list_tokens do
    Benchee.run(%{"Fiat value type performance" => fn _ -> Repo.all(Token) end},
      inputs:
        for with_market_data <- [false, true],
            enabled_token_fetcher? when with_market_data or not enabled_token_fetcher? <- [false, true],
            token_count <- [50, 100, 10000],
            into: %{} do
          {"#{token_count} tokens#{if with_market_data, do: " with market data", else: ""}#{if enabled_token_fetcher?, do: " with enabled token fetcher", else: ""}",
           %{
             token_count: token_count,
             with_market_data: with_market_data,
             enabled_token_fetcher: enabled_token_fetcher?
           }}
        end,
      before_scenario: fn %{
                            token_count: token_count,
                            with_market_data: with_market_data,
                            enabled_token_fetcher: enabled_token_fetcher?
                          } = input ->
        :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo, ownership_timeout: :infinity)

        Repo.delete_all(Token)

        market_data = fn i ->
          if with_market_data do
            [fiat_value: Decimal.new(i), circulating_market_cap: Decimal.new(i)]
          else
            [fiat_value: nil, circulating_market_cap: nil]
          end
        end

        1..token_count
        |> Enum.each(fn i ->
          insert(:token, market_data.(i))
        end)

        if enabled_token_fetcher? do
          Application.put_env(:explorer, Explorer.Market.Source, tokens_source: Explorer.Market.Source.OneCoinSource)
          TokenFetcher.start_link([])
        end
      end,
      load: @path,
      save: [
        path: @path,
        tag: "fiat-value-no-check"
      ],
      time: 5,
      formatters: [Benchee.Formatters.Console]
    )
  end
end

Explorer.Chain.FiatValueBenchmark.list_tokens()
