defmodule Explorer.GraphQL do
  @moduledoc """
  The GraphQL context.
  """

  import Ecto.Query,
    only: [
      from: 2,
      order_by: 3,
      or_where: 3,
      subquery: 1,
      where: 3
    ]

  alias Explorer.Celo.Util

  alias Explorer.Chain.{
    Address,
    Block,
    CeloAccount,
    CeloClaims,
    CeloParams,
    CeloVoters,
    CeloWalletAccounts,
    Hash,
    InternalTransaction,
    Token,
    TokenTransfer,
    Transaction
  }

  alias Explorer.{Chain, Repo}

  alias Explorer.Chain.Address.CoinBalance

  @doc """
  Returns a query to fetch transactions with a matching `to_address_hash`,
  `from_address_hash`, or `created_contract_address_hash` field for a given address hash.

  Orders transactions by descending block number and index.
  """
  @spec address_to_transactions_query(Hash.Address.t()) :: Ecto.Query.t()
  def address_to_transactions_query(address_hash) do
    Transaction
    |> order_by([transaction], desc: transaction.block_number, desc: transaction.index)
    |> where([transaction], transaction.to_address_hash == ^address_hash)
    |> or_where([transaction], transaction.from_address_hash == ^address_hash)
    |> or_where([transaction], transaction.created_contract_address_hash == ^address_hash)
  end

  def address_to_account_query(address_hash) do
    CeloAccount
    |> where([account], account.address == ^address_hash)
  end

  def address_to_validator_query(address_hash) do
    Chain.celo_validator_query()
    |> where([account], account.address == ^address_hash)
  end

  def address_to_affiliates_query(address_hash) do
    Chain.celo_validator_query()
    |> where([account], account.group_address_hash == ^address_hash)
  end

  def address_to_claims_query(address_hash) do
    CeloClaims
    |> where([account], account.address == ^address_hash)
  end

  def address_to_validator_group_query(address_hash) do
    Chain.celo_validator_group_query()
    |> where([account], account.address == ^address_hash)
  end

  def address_query(address_hash) do
    Address
    |> where([account], account.hash == ^address_hash)
  end

  @doc """
  Returns an internal transaction for a given transaction hash and index.
  """
  @spec get_internal_transaction(map()) :: {:ok, InternalTransaction.t()} | {:error, String.t()}
  def get_internal_transaction(%{transaction_hash: _, index: _} = clauses) do
    if internal_transaction = Repo.get_by(InternalTransaction.where_nonpending_block(), clauses) do
      {:ok, internal_transaction}
    else
      {:error, "Internal transaction not found."}
    end
  end

  @doc """
  Returns a query to fetch internal transactions for a given transaction.

  Orders internal transactions by ascending index.
  """
  @spec transaction_to_internal_transactions_query(Transaction.t()) :: Ecto.Query.t()
  def transaction_to_internal_transactions_query(%Transaction{
        hash: %Hash{byte_count: unquote(Hash.Full.byte_count())} = hash
      }) do
    query =
      from(
        it in InternalTransaction,
        inner_join: t in assoc(it, :transaction),
        order_by: [asc: it.index],
        where: it.transaction_hash == ^hash,
        select: it
      )

    query
    |> InternalTransaction.where_nonpending_block()
    |> Chain.where_transaction_has_multiple_internal_transactions()
  end

  @doc """
  Returns a token transfer for a given transaction hash and log index.
  """
  @spec get_token_transfer(map()) :: {:ok, TokenTransfer.t()} | {:error, String.t()}
  def get_token_transfer(%{transaction_hash: _, log_index: _} = clauses) do
    if token_transfer = Repo.get_by(TokenTransfer, clauses) do
      {:ok, token_transfer}
    else
      {:error, "Token transfer not found."}
    end
  end

  @doc """
  Returns a query to fetch token transfers for a token contract address hash.

  Orders token transfers by descending block number.
  """
  @spec list_token_transfers_query(Hash.t()) :: Ecto.Query.t()
  def list_token_transfers_query(%Hash{byte_count: unquote(Hash.Address.byte_count())} = token_contract_address_hash) do
    from(
      tt in TokenTransfer,
      inner_join: t in assoc(tt, :transaction),
      where: tt.token_contract_address_hash == ^token_contract_address_hash,
      order_by: [desc: tt.block_number],
      select: tt
    )
  end

  def group_voters_query(group_address) do
    query =
      from(addr in CeloAccount,
        join: account in CeloVoters,
        on: account.voter_address_hash == addr.address,
        where: account.group_address_hash == ^group_address,
        where: account.total > ^0,
        select_merge: %{
          votes: account.total
        }
      )

    query
  end

  def account_voted_query(account_address) do
    group = Chain.celo_validator_group_query()

    query =
      from(addr in subquery(group),
        join: account in CeloVoters,
        on: account.group_address_hash == addr.address,
        where: account.voter_address_hash == ^account_address,
        where: account.total > ^0,
        select_merge: %{
          votes: account.total
        }
      )

    query
  end

  def list_gold_transfers_query do
    token_contract_names = ["goldToken"]
    token_symbols = ["cGLD"]

    from(
      tt in TokenTransfer,
      join: t in CeloParams,
      where: tt.token_contract_address_hash == t.address_value,
      where: t.name == "goldToken",
      inner_join:
        tkn in fragment(
          """
          (
            WITH token_names AS (
              SELECT contract_name, token_symbol FROM unnest(?::text[], ?::text[]) t (contract_name, token_symbol)
            ) SELECT * FROM token_names
          )
          """,
          ^token_contract_names,
          ^token_symbols
        ),
      on: t.name == tkn.contract_name,
      inner_join: tx in Transaction,
      as: :transaction,
      on: tx.hash == tt.transaction_hash,
      inner_join: b in Block,
      on: tt.block_number == b.number,
      left_join: wf in CeloWalletAccounts,
      on: tt.from_address_hash == wf.wallet_address_hash,
      left_join: wt in CeloWalletAccounts,
      on: tt.to_address_hash == wt.wallet_address_hash,
      select: %{
        transaction_hash: tt.transaction_hash,
        from_address_hash: tt.from_address_hash,
        to_address_hash: tt.to_address_hash,
        value: tt.amount,
        comment: tt.comment,
        block_number: tt.block_number
      },
      order_by: [desc: tt.block_number, desc: tt.amount, desc: tt.log_index]
    )
  end

  def list_gold_transfers_query_for_address(address_hash) do
    list_gold_transfers_query()
    |> where([t], t.from_address_hash == ^address_hash or t.to_address_hash == ^address_hash)
  end

  def txtransfers_query_for_address(address_hash) do
    query =
      txtransfers_query()
      |> where([t], t.to_address_hash == ^address_hash or t.from_address_hash == ^address_hash)

    from(
      t in subquery(query),
      order_by: [desc: t.block_number, asc: t.nonce]
    )
  end

  def token_txtransfers_query_for_address(address_hash) do
    query =
      token_txtransfers_query()
      |> where([t], t.to_address_hash == ^address_hash or t.from_address_hash == ^address_hash)
  end

  def celo_tx_transfers_query_by_txhash(tx_hash) do
    query = celo_tx_transfers_query()

    from(
      t in subquery(query),
      where: t.transaction_hash == ^tx_hash,
      order_by: [t.log_index]
    )
  end

  def celo_tx_transfers_query_by_address(address_hash) do
    celo_tx_transfers_query()
    |> where([t], t.from_address_hash == ^address_hash or t.to_address_hash == ^address_hash)
    |> order_by([transaction: t], desc: t.block_number, asc: t.nonce)
  end

  def token_tx_transfers_query_by_txhash(tx_hash) do
    query = token_tx_transfers_query()

    from(
      t in subquery(query),
      where: t.transaction_hash == ^tx_hash,
      order_by: [t.log_index]
    )
  end

  def token_tx_transfers_query_by_address(address_hash) do
    token_tx_transfers_query()
    |> where([t], t.from_address_hash == ^address_hash or t.to_address_hash == ^address_hash)
    |> order_by([transaction: t], desc: t.block_number, asc: t.nonce)
  end

  def txtransfers_query do
    token_contract_names = Util.get_token_contract_names()

    from(
      tt in TokenTransfer,
      join: t in CeloParams,
      where: tt.token_contract_address_hash == t.address_value,
      where: t.name in ^token_contract_names,
      where: not is_nil(tt.transaction_hash),
      inner_join: tx in Transaction,
      on: tx.hash == tt.transaction_hash,
      inner_join: b in Block,
      on: tx.block_hash == b.hash,
      left_join: token in Token,
      on: tx.gas_currency_hash == token.contract_address_hash,
      select: %{
        transaction_hash: tt.transaction_hash,
        to_address_hash: tt.to_address_hash,
        from_address_hash: tt.from_address_hash,
        gas_used: tx.gas_used,
        gas_price: tx.gas_price,
        fee_currency: tx.gas_currency_hash,
        fee_token: fragment("coalesce(?, 'CELO')", token.symbol),
        gateway_fee: tx.gateway_fee,
        gateway_fee_recipient: tx.gas_fee_recipient_hash,
        timestamp: b.timestamp,
        input: tx.input,
        nonce: tx.nonce,
        block_number: tt.block_number
      },
      distinct: [desc: tt.block_number, desc: tt.transaction_hash],
      # to get the ordering from distinct clause, something is needed here too
      order_by: [desc: tt.from_address_hash, desc: tt.to_address_hash]
    )
  end

  def token_txtransfers_query do
    from(
      tt in TokenTransfer,
      where: not is_nil(tt.transaction_hash),
      inner_join: tx in Transaction,
      on: tx.hash == tt.transaction_hash,
      inner_join: b in Block,
      on: tx.block_hash == b.hash,
      left_join: token in Token,
      on: tx.gas_currency_hash == token.contract_address_hash,
      select: %{
        transaction_hash: tt.transaction_hash,
        to_address_hash: tt.to_address_hash,
        from_address_hash: tt.from_address_hash,
        gas_used: tx.gas_used,
        gas_price: tx.gas_price,
        fee_currency: tx.gas_currency_hash,
        fee_token: fragment("coalesce(?, 'CELO')", token.symbol),
        gateway_fee: tx.gateway_fee,
        gateway_fee_recipient: tx.gas_fee_recipient_hash,
        timestamp: b.timestamp,
        input: tx.input,
        nonce: tx.nonce,
        block_number: tt.block_number
      },
      distinct: [desc: tt.block_number, desc: tt.transaction_hash],
      # to get the ordering from distinct clause, something is needed here too
      order_by: [asc: tx.nonce, desc: tt.from_address_hash, desc: tt.to_address_hash]
    )
  end

  def token_tx_transfers_query do
    from(
      tt in TokenTransfer,
      inner_join: tx in Transaction,
      as: :transaction,
      on: tx.hash == tt.transaction_hash,
      inner_join: b in Block,
      on: tt.block_number == b.number,
      left_join: wf in CeloWalletAccounts,
      on: tt.from_address_hash == wf.wallet_address_hash,
      left_join: wt in CeloWalletAccounts,
      on: tt.to_address_hash == wt.wallet_address_hash,
      left_join: token in Token,
      on: tt.token_contract_address_hash == token.contract_address_hash,
      select: %{
        gas_used: tx.gas_used,
        gas_price: tx.gas_price,
        timestamp: b.timestamp,
        input: tx.input,
        transaction_hash: tt.transaction_hash,
        from_address_hash: tt.from_address_hash,
        to_address_hash: tt.to_address_hash,
        from_account_hash: wf.account_address_hash,
        to_account_hash: wt.account_address_hash,
        log_index: tt.log_index,
        value: tt.amount,
        comment: tt.comment,
        token: token.symbol,
        token_address: token.contract_address_hash,
        nonce: tx.nonce,
        block_number: tt.block_number,
        token_type: token.type,
        token_id: tt.token_id
      },
      order_by: [desc: tt.block_number, desc: tt.amount, desc: tt.log_index]
    )
  end

  def celo_tx_transfers_query do
    token_contract_names = Util.get_token_contract_names()
    token_symbols = Util.get_token_contract_symbols()

    from(
      tt in TokenTransfer,
      join: t in CeloParams,
      where: tt.token_contract_address_hash == t.address_value,
      where: t.name in ^token_contract_names,
      inner_join:
        tkn in fragment(
          """
          (
            WITH token_names AS (
              SELECT contract_name, token_symbol FROM unnest(?::text[], ?::text[]) t (contract_name, token_symbol)
            ) SELECT * FROM token_names
          )
          """,
          ^token_contract_names,
          ^token_symbols
        ),
      on: t.name == tkn.contract_name,
      inner_join: tx in Transaction,
      as: :transaction,
      on: tx.hash == tt.transaction_hash,
      inner_join: b in Block,
      on: tt.block_number == b.number,
      left_join: wf in CeloWalletAccounts,
      on: tt.from_address_hash == wf.wallet_address_hash,
      left_join: wt in CeloWalletAccounts,
      on: tt.to_address_hash == wt.wallet_address_hash,
      left_join: token in Token,
      on: tt.token_contract_address_hash == token.contract_address_hash,
      select: %{
        gas_used: tx.gas_used,
        gas_price: tx.gas_price,
        timestamp: b.timestamp,
        input: tx.input,
        transaction_hash: tt.transaction_hash,
        from_address_hash: tt.from_address_hash,
        to_address_hash: tt.to_address_hash,
        from_account_hash: wf.account_address_hash,
        to_account_hash: wt.account_address_hash,
        log_index: tt.log_index,
        value: tt.amount,
        comment: tt.comment,
        token: tkn.token_symbol,
        token_address: tt.token_contract_address_hash,
        nonce: tx.nonce,
        block_number: tt.block_number,
        token_type: token.type,
        token_id: tt.token_id
      },
      order_by: [desc: tt.block_number, desc: tt.amount, desc: tt.log_index]
    )
  end

  def list_coin_balances_query(address_hash) do
    from(
      cb in CoinBalance,
      where: cb.address_hash == ^address_hash,
      where: not is_nil(cb.value),
      inner_join: b in Block,
      on: cb.block_number == b.number,
      order_by: [desc: :block_number],
      select_merge: %{delta: %{value: fragment("value - coalesce(lag(value, 1) over (order by block_number), 0)")}},
      select_merge: %{block_timestamp: b.timestamp}
    )
  end
end
