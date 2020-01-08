defmodule BlockScoutWeb.Resolvers.CeloUtil do
  @moduledoc false

  alias Explorer.Chain
  alias Explorer.Chain.{CeloAccount, CeloValidator}

  def get_usd(%CeloAccount{address: hash}, _, _) do
    Chain.get_token_balance(hash, "cUSD")
  end

  def get_elected(%CeloValidator{address: hash}, _, _) do
    Chain.get_latest_validating_block(hash)
  end

  def get_latest_block(_, _, _) do
    Chain.get_latest_history_block()
  end

  def get_online(%CeloValidator{address: hash}, _, _) do
    Chain.get_latest_active_block(hash)
  end
end
