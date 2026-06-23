# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule BlockScoutWeb.Schemas.API.V2.Stats.GasPriceInfo do
  @moduledoc """
  Detailed gas price info for a single tier, as produced by
  `Explorer.Chain.Cache.GasPriceOracle.compose_gas_price/5`.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.General
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StatsGasPriceInfo",
    type: :object,
    properties: %{
      price: %Schema{type: :number, format: :float, nullable: true, description: "Estimated gas price, in Gwei."},
      time: %Schema{type: :number, format: :float, nullable: true, description: "Estimated time until inclusion, in ms."},
      base_fee: %Schema{type: :number, format: :float, nullable: true, description: "Base fee, in Gwei."},
      priority_fee: %Schema{
        type: :number,
        format: :float,
        nullable: true,
        description: "Priority fee including base fee, in Gwei."
      },
      fiat_price: General.FloatStringNullable,
      priority_fee_wei: General.IntegerStringNullable,
      wei: General.IntegerStringNullable
    },
    required: [:price, :time, :base_fee, :priority_fee, :fiat_price, :priority_fee_wei, :wei],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Stats.GasPrices.Simple do
  @moduledoc """
  Gas prices per tier as plain Gwei numbers — the default `/api/v2/stats` shape
  (when the `updated-gas-oracle: true` request header is absent).
  """
  require OpenApiSpex

  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StatsGasPricesSimple",
    description: "Gas prices per tier as plain Gwei values.",
    type: :object,
    properties: %{
      slow: %Schema{type: :number, format: :float, nullable: true},
      average: %Schema{type: :number, format: :float, nullable: true},
      fast: %Schema{type: :number, format: :float, nullable: true}
    },
    required: [:slow, :average, :fast],
    additionalProperties: false
  })
end

defmodule BlockScoutWeb.Schemas.API.V2.Stats.GasPrices.Detailed do
  @moduledoc """
  Gas prices per tier as detailed objects — returned by `/api/v2/stats` with the
  `updated-gas-oracle: true` request header.
  """
  require OpenApiSpex

  alias BlockScoutWeb.Schemas.API.V2.Stats.GasPriceInfo
  alias OpenApiSpex.Schema

  OpenApiSpex.schema(%{
    title: "StatsGasPricesDetailed",
    description: "Gas prices per tier as detailed objects.",
    type: :object,
    properties: %{
      slow: %Schema{allOf: [GasPriceInfo], nullable: true},
      average: %Schema{allOf: [GasPriceInfo], nullable: true},
      fast: %Schema{allOf: [GasPriceInfo], nullable: true}
    },
    required: [:slow, :average, :fast],
    additionalProperties: false
  })
end
