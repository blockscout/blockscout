# SPDX-License-Identifier: LicenseRef-Blockscout

defmodule Explorer.Wallet do
  @moduledoc """
  Wallet module for managing blockchain wallets and transactions.

  This module provides core wallet functionality including:
  - Wallet creation and management
  - Balance tracking
  - Transaction history
  - Multi-chain support
  """

  alias Explorer.Wallet.{Account, Balance, Transaction}
  alias Explorer.Repo

  @doc """
  Create a new wallet for a user.

  ## Parameters
    - user_id: Unique identifier for the user
    - chain_id: Blockchain network ID (1 for Ethereum mainnet, etc.)
    - wallet_type: Type of wallet (:hot, :cold, :hardware)

  ## Returns
    - {:ok, wallet} on success
    - {:error, reason} on failure
  """
  def create_wallet(user_id, chain_id, wallet_type \\ :hot) do
    case Account.create(user_id, chain_id, wallet_type) do
      {:ok, account} ->
        {:ok, account}
      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get wallet by address and chain.
  """
  def get_wallet(address, chain_id) do
    Account.get_by_address_and_chain(address, chain_id)
  end

  @doc """
  Get wallet balance.
  """
  def get_balance(wallet_address, chain_id, token_contract \\ nil) do
    Balance.get_balance(wallet_address, chain_id, token_contract)
  end

  @doc """
  Get transaction history for a wallet.
  """
  def get_transactions(wallet_address, chain_id, opts \\ []) do
    Transaction.list_by_wallet(wallet_address, chain_id, opts)
  end

  @doc """
  Import an existing wallet.
  """
  def import_wallet(user_id, private_key_encrypted, chain_id) do
    Account.import(user_id, private_key_encrypted, chain_id)
  end
end
