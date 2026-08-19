# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Stats.TransactionsChartDataPoint do
  @moduledoc """
  Single data point of the `/api/v2/stats/charts/transactions` chart.
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StatsTransactionsChartDataPoint",
    type: :object,
    properties: %{
      date: %Schema{type: :string, format: :date, nullable: false, description: "Day the data point refers to."},
      transactions_count: %Schema{
        type: :integer,
        minimum: 0,
        nullable: true,
        description: "Number of transactions on that day."
      }
    },
    required: [:date, :transactions_count],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Stats.MarketChartDataPoint do
  @moduledoc """
  Single data point of the `/api/v2/stats/charts/market` chart.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StatsMarketChartDataPoint",
    type: :object,
    properties: %{
      date: %Schema{type: :string, format: :date, nullable: false, description: "Day the data point refers to."},
      closing_price: General.FloatStringNullable,
      market_cap: General.FloatStringNullable,
      tvl: General.FloatStringNullable
    },
    required: [:date, :closing_price, :market_cap, :tvl],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Stats.SecondaryCoinMarketChartDataPoint do
  @moduledoc """
  Single data point of the `/api/v2/stats/charts/secondary-coin-market` chart.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StatsSecondaryCoinMarketChartDataPoint",
    type: :object,
    properties: %{
      date: %Schema{type: :string, format: :date, nullable: false, description: "Day the data point refers to."},
      closing_price: General.FloatStringNullable
    },
    required: [:date, :closing_price],
    additionalProperties: false
  })
end
