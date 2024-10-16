defmodule Explorer.GraphQL.Celo do
  @moduledoc """
  Defines Ecto queries to fetch Celo blockchain data for the legacy GraphQL
  schema.

  Includes functions to construct queries for token transfers and transactions.
  """

  import Ecto.Query,
    only: [from: 2, order_by: 3, where: 3, subquery: 1]

  alias Explorer.Chain.{
    Block,
    Hash,
    Token,
    TokenTransfer,
    Transaction
  }

  @doc """
  Constructs a paginated query for token transfers involving a specific address.
  """
  @spec token_transaction_transfers_query_for_address(Hash.Address.t(), integer(), integer()) :: Ecto.Query.t()
  def token_transaction_transfers_query_for_address(address_hash, offset, limit) do
    page = floor(offset / limit) + 1
    growing_limit = limit * (page + 1)

    tokens =
      from(
        tt in TokenTransfer,
        where: not is_nil(tt.transaction_hash),
        where: tt.to_address_hash == ^address_hash,
        or_where: tt.from_address_hash == ^address_hash,
        select: %{
          transaction_hash: tt.transaction_hash,
          block_number: tt.block_number,
          to_address_hash: tt.to_address_hash,
          from_address_hash: tt.from_address_hash
        },
        distinct: [desc: tt.block_number, desc: tt.transaction_hash],
        order_by: [
          desc: tt.block_number,
          desc: tt.transaction_hash,
          desc: tt.from_address_hash,
          desc: tt.to_address_hash
        ],
        limit: ^growing_limit
      )

    query =
      from(
        tt in subquery(tokens),
        as: :token_transfer,
        inner_join: transaction in Transaction,
        as: :transaction,
        on: transaction.hash == tt.transaction_hash,
        inner_join: b in Block,
        on: transaction.block_hash == b.hash,
        left_join: token in Token,
        on: transaction.gas_token_contract_address_hash == token.contract_address_hash,
        select: %{
          transaction_hash: tt.transaction_hash,
          to_address_hash: tt.to_address_hash,
          from_address_hash: tt.from_address_hash,
          gas_used: transaction.gas_used,
          gas_price: transaction.gas_price,
          fee_currency: transaction.gas_token_contract_address_hash,
          fee_token: fragment("coalesce(?, 'CELO')", token.symbol),
          # gateway_fee: transaction.gateway_fee,
          # gateway_fee_recipient: transaction.gas_fee_recipient_hash,
          timestamp: b.timestamp,
          input: transaction.input,
          nonce: transaction.nonce,
          block_number: tt.block_number
        }
      )

    query
    |> order_by(
      [transaction: t],
      desc: t.block_number,
      desc: t.hash,
      asc: t.nonce,
      desc: t.from_address_hash,
      desc: t.to_address_hash
    )
  end

  @doc """
  Constructs a query to fetch token transfers within a given transaction.

  ## Parameters
    - transaction_hash: the hash of the transaction

  ## Returns
   - Ecto query
  """
  @spec token_transaction_transfers_query_by_transaction_hash(Hash.Full.t()) :: Ecto.Query.t()
  def token_transaction_transfers_query_by_transaction_hash(transaction_hash) do
    query = token_transaction_transfers_query()

    from(
      t in subquery(query),
      where: t.transaction_hash == ^transaction_hash,
      order_by: [t.log_index]
    )
  end

  @doc """
  Constructs a query for token transfers filtered by a specific address.
  """
  @spec token_transaction_transfers_query_by_address(Hash.Address.t()) :: Ecto.Query.t()
  def token_transaction_transfers_query_by_address(address_hash) do
    token_transaction_transfers_query()
    |> where([t], t.from_address_hash == ^address_hash or t.to_address_hash == ^address_hash)
    |> order_by([transaction: t], desc: t.block_number, asc: t.nonce)
  end

  @doc """
  Constructs a query to fetch detailed token transfer information.
  """
  @spec token_transaction_transfers_query() :: Ecto.Query.t()
  def token_transaction_transfers_query do
    from(
      tt in TokenTransfer,
      inner_join: transaction in Transaction,
      as: :transaction,
      on: transaction.hash == tt.transaction_hash,
      inner_join: b in Block,
      on: tt.block_number == b.number,
      # left_join: wf in CeloWalletAccounts,
      # on: tt.from_address_hash == wf.wallet_address_hash,
      # left_join: wt in CeloWalletAccounts,
      # on: tt.to_address_hash == wt.wallet_address_hash,
      left_join: token in Token,
      on: tt.token_contract_address_hash == token.contract_address_hash,
      select: %{
        gas_used: transaction.gas_used,
        gas_price: transaction.gas_price,
        timestamp: b.timestamp,
        input: transaction.input,
        transaction_hash: tt.transaction_hash,
        from_address_hash: tt.from_address_hash,
        to_address_hash: tt.to_address_hash,
        # from_account_hash: wf.account_address_hash,
        # to_account_hash: wt.account_address_hash,
        log_index: tt.log_index,
        value: tt.amount,
        # comment: tt.comment,
        token: token.symbol,
        token_address: token.contract_address_hash,
        nonce: transaction.nonce,
        block_number: tt.block_number,
        token_type: token.type,
        token_id: fragment("(COALESCE(?, ARRAY[]::Decimal[]))[1]", tt.token_ids)
      },
      order_by: [desc: tt.block_number, desc: tt.amount, desc: tt.log_index]
    )
  end
end
