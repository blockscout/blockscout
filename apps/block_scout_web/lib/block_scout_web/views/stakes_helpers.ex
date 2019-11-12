defmodule BlockScoutWeb.StakesHelpers do
  @moduledoc """
  Helpers for staking templates
  """
  alias BlockScoutWeb.CldrHelper.Number
  alias Explorer.Chain.Cache.BlockNumber
  alias Explorer.Chain.Token
  alias Phoenix.HTML
  alias Timex.Duration

  def amount_ratio(pool) do
    zero = Decimal.new(0)

    case pool do
      %{total_staked_amount: ^zero} ->
        0

      %{total_staked_amount: total_staked_amount, self_staked_amount: self_staked} ->
        amount = Decimal.to_float(total_staked_amount)
        self = Decimal.to_float(self_staked)
        self / amount * 100
    end
  end

  def estimated_unban_day(banned_until, average_block_time) do
    block_time = Duration.to_seconds(average_block_time)

    try do
      during_sec = (banned_until - BlockNumber.get_max()) * block_time
      now = DateTime.utc_now() |> DateTime.to_unix()
      date = DateTime.from_unix!(trunc(now + during_sec))
      Timex.format!(date, "%d %b %Y", :strftime)
    rescue
      _e ->
        DateTime.utc_now()
        |> Timex.format!("%d %b %Y", :strftime)
    end
  end

  def list_title(:validator), do: Gettext.dgettext(BlockScoutWeb.Gettext, "default", "Validators")
  def list_title(:active), do: Gettext.dgettext(BlockScoutWeb.Gettext, "default", "Active Pools")
  def list_title(:inactive), do: Gettext.dgettext(BlockScoutWeb.Gettext, "default", "Inactive Pools")

  def format_token_amount(amount, token, options \\ [])
  def format_token_amount(nil, _token, _options), do: "-"
  def format_token_amount(amount, nil, options), do: format_token_amount(amount, %Token{}, options)

  def format_token_amount(amount, token, options) when is_integer(amount) do
    amount
    |> Decimal.new()
    |> format_token_amount(token, options)
  end

  def format_token_amount(%Decimal{} = amount, %Token{} = token, options) do
    symbol = if Keyword.get(options, :symbol, true), do: " #{token.symbol}"
    digits = Keyword.get(options, :digits, 5)
    ellipsize = Keyword.get(options, :ellipsize, true)
    decimals = if token.decimals, do: Decimal.to_integer(token.decimals), else: 0

    reduced =
      amount.sign
      |> Decimal.new(amount.coef, amount.exp - decimals)
      |> Decimal.reduce()

    if digits >= -reduced.exp or not ellipsize do
      "#{Number.to_string!(reduced, fractional_digits: min(digits, -reduced.exp))}#{symbol}"
    else
      HTML.raw(~s"""
        <span
          data-placement="top"
          data-toggle="tooltip"
          title="#{Number.to_string!(reduced, fractional_digits: -reduced.exp)}#{symbol}">
          #{Number.to_string!(reduced, fractional_digits: digits)}...#{symbol}
        </span>
      """)
    end
  end
end
