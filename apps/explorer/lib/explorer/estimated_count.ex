defmodule Explorer.EstimatedCount do
  @moduledoc """
  Estimated count of schema that take too long to count precisely.
  """

  alias Ecto.Adapters.SQL
  alias Explorer.Repo

  @doc """
  Estimated count of `t:Explorer.Chain.Address.t/0`.

  Estimated count of addresses using the `addresses` table statistics.
  """
  @spec address() :: non_neg_integer()
  def address do
    estimated_count("addresses")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Balance.t/0`.

  Estimated count of balances using the `balances` table statistics.
  """
  @spec balance() :: non_neg_integer()
  def balance do
    estimated_count("balances")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Block.t/0`.

  Estimated count of blocks using the `blocks` table statistics.
  """
  @spec block() :: non_neg_integer()
  def block do
    estimated_count("blocks")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.InternalTransaction.t/0`.

  Estimated count of internal transactions using the `internal_transactions` table statistics.
  """
  @spec internal_transaction() :: non_neg_integer()
  def internal_transaction do
    estimated_count("internal_transactions")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Log.t/0`.

  Estimated count of logs using the `logs` table statistics.
  """
  @spec log() :: non_neg_integer()
  def log do
    estimated_count("logs")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.SmartContract.t/0`.

  Estimated count of smart contract using the `smart_contracts` table statistics.
  """
  @spec smart_contract() :: non_neg_integer()
  def smart_contract do
    estimated_count("smart_contracts")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Token.t/0`.

  Estimated count of token using the `tokens` table statistics.
  """
  @spec token() :: non_neg_integer()
  def token do
    estimated_count("tokens")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Address.TokenBalance.t/0`.

  Estimated count of token balances using the `address_token_balances` table statistics.
  """
  @spec token_balance() :: non_neg_integer()
  def token_balance do
    estimated_count("address_token_balances")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.TokenTransfer.t/0`.

  Estimated count of token transfers using the `address_token_transfers` table statistics.
  """
  @spec token_transfer() :: non_neg_integer()
  def token_transfer do
    estimated_count("token_transfers")
  end

  @doc """
  Estimated count of `t:Explorer.Chain.Transaction.t/0`.

  Estimated count of both collated and pending transactions using the `transactions` table statistics.
  """
  @spec transaction() :: non_neg_integer()
  def transaction do
    estimated_count("transactions")
  end

  @spec estimated_count(String.t()) :: non_neg_integer()
  defp estimated_count(table) do
    %Postgrex.Result{rows: [[rows]]} =
      SQL.query!(Repo, "SELECT reltuples::BIGINT AS estimate FROM pg_class WHERE relname='#{table}'")

    rows
  end
end
