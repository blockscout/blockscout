# SPDX-License-Identifier: LicenseRef-Blockscout

defmodule Explorer.Wallet.Account do
  @moduledoc """
  Schema and functions for managing wallet accounts.

  Tracks wallet ownership, associated users, and chain information.
  """

  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  alias Explorer.Repo
  alias Explorer.Chain.Hash.Address

  schema "wallet_accounts" do
    field :user_id, :integer
    field :address, Address.t()
    field :chain_id, :integer
    field :wallet_type, Ecto.Enum, values: [:hot, :cold, :hardware]
    field :public_key, :string
    field :encrypted_private_key, :string
    field :is_active, :boolean, default: true
    field :label, :string
    field :created_at_block, :integer

    timestamps(type: :utc_datetime_usec)
  end

  @doc false
  def changeset(account, attrs) do
    account
    |> cast(attrs, [
      :user_id,
      :address,
      :chain_id,
      :wallet_type,
      :public_key,
      :encrypted_private_key,
      :is_active,
      :label,
      :created_at_block
    ])
    |> validate_required([:user_id, :address, :chain_id, :wallet_type, :public_key])
    |> unique_constraint([:address, :chain_id], name: :wallet_accounts_address_chain_id_index)
  end

  @doc """
  Create a new wallet account.
  """
  def create(user_id, chain_id, wallet_type \\ :hot) do
    # Generate new keypair
    case generate_keypair() do
      {:ok, {public_key, encrypted_private_key}} ->
        address = derive_address(public_key)

        attrs = %{
          user_id: user_id,
          address: address,
          chain_id: chain_id,
          wallet_type: wallet_type,
          public_key: public_key,
          encrypted_private_key: encrypted_private_key,
          is_active: true
        }

        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Import an existing wallet with encrypted private key.
  """
  def import(user_id, encrypted_private_key, chain_id) do
    case derive_public_key_from_encrypted(encrypted_private_key) do
      {:ok, public_key} ->
        address = derive_address(public_key)

        attrs = %{
          user_id: user_id,
          address: address,
          chain_id: chain_id,
          wallet_type: :hot,
          public_key: public_key,
          encrypted_private_key: encrypted_private_key,
          is_active: true
        }

        %__MODULE__{}
        |> changeset(attrs)
        |> Repo.insert()

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Get wallet by address and chain ID.
  """
  def get_by_address_and_chain(address, chain_id) do
    __MODULE__
    |> where([a], a.address == ^address and a.chain_id == ^chain_id and a.is_active)
    |> Repo.one()
  end

  @doc """
  List all wallets for a user.
  """
  def list_by_user(user_id) do
    __MODULE__
    |> where([a], a.user_id == ^user_id and a.is_active)
    |> Repo.all()
  end

  # Private functions

  defp generate_keypair do
    # TODO: Implement keypair generation using libsecp256k1
    # For now, return a placeholder
    {:ok, {"public_key_placeholder", "encrypted_private_key_placeholder"}}
  end

  defp derive_address(public_key) do
    # TODO: Implement address derivation from public key
    # For Ethereum: keccak256(public_key) -> take last 20 bytes
    "0x" <> String.slice(public_key, 0..39)
  end

  defp derive_public_key_from_encrypted(_encrypted_private_key) do
    # TODO: Decrypt private key and derive public key
    {:ok, "public_key_placeholder"}
  end
end
