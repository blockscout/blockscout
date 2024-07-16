defmodule Explorer.Chain.Validator do
  @moduledoc """
    Tracks info about POA validator
  """

  use Explorer.Schema
  alias Explorer.Chain.Hash.Address
  alias Explorer.{Chain, Repo}

  @primary_key false
  typed_schema "validators" do
    field(:address_hash, Address, primary_key: true, null: false)
    field(:is_validator, :boolean)
    field(:payout_key_hash, Address)
    field(:info_updated_at_block, :integer)

    timestamps()
  end

  def insert_or_update(nil, attrs) do
    attrs
    |> changeset()
    |> Repo.insert()
  end

  def insert_or_update(validator, attrs) do
    validator
    |> changeset(attrs)
    |> Repo.update()
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  @required_attrs ~w(address_hash)a
  @optional_attrs ~w(is_validator payout_key_hash info_updated_at_block)a
  def changeset(%__MODULE__{} = constant, attrs) do
    constant
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address_hash)
  end

  def get_validator_by_address_hash(address_hash, options \\ []) do
    __MODULE__
    |> where([validator], validator.address_hash == ^address_hash)
    |> Chain.select_repo(options).one()
  end

  def drop_all_validators do
    __MODULE__
    |> Repo.delete_all()
  end
end
