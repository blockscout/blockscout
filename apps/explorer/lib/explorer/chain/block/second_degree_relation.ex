defmodule Explorer.Chain.Block.SecondDegreeRelation do
  @moduledoc """
  A [second-degree relative](https://en.wikipedia.org/wiki/Second-degree_relative) is a relative where the share
  point is the parent's parent block in the chain.

  For Ethereum, nephews are rewarded for included their uncles.

  Uncles occur when a Proof-of-Work proof is completed slightly late, but before the next block is completes, so the
  network knows about the late proof and can credit as an uncle in the next block.

  This schema is the join schema between the `nephew` and the `uncle` it is is including the `uncle`.  The actual
  `uncle` block is still a normal `t:Explorer.Chain.Block.t/0`.
  """

  use Explorer.Schema

  alias Explorer.Chain.{Block, Hash}

  @optional_fields ~w(uncle_fetched_at)a
  @required_fields ~w(nephew_hash uncle_hash index)a
  @allowed_fields @optional_fields ++ @required_fields

  @typedoc """
   * `nephew` - `t:Explorer.Chain.Block.t/0` that included `hash` as an uncle.
   * `nephew_hash` - foreign key for `nephew_block`.
   * `uncle` - the uncle block.  Maybe `nil` when `uncle_fetched_at` is `nil`.  It could not be `nil` if the
     `uncle_hash` was fetched for some other reason already.
   * `uncle_fetched_at` - when `t:Explorer.Chain.Block.t/0` for `uncle_hash` was confirmed as fetched.
   * `uncle_hash` - foreign key for `uncle`.
   * `index` - index of the uncle within its nephew. Can be `nil` for blocks fetched before this field was added.
  """
  @type t ::
          %__MODULE__{
            nephew: %Ecto.Association.NotLoaded{} | Block.t(),
            nephew_hash: Hash.Full.t(),
            uncle: %Ecto.Association.NotLoaded{} | Block.t() | nil,
            uncle_fetched_at: nil,
            uncle_hash: Hash.Full.t(),
            index: non_neg_integer() | nil
          }
          | %__MODULE__{
              nephew: %Ecto.Association.NotLoaded{} | Block.t(),
              nephew_hash: Hash.Full.t(),
              uncle: %Ecto.Association.NotLoaded{} | Block.t(),
              uncle_fetched_at: DateTime.t(),
              uncle_hash: Hash.Full.t(),
              index: non_neg_integer() | nil
            }

  @primary_key false
  schema "block_second_degree_relations" do
    field(:uncle_fetched_at, :utc_datetime_usec)
    field(:index, :integer)

    belongs_to(:nephew, Block, foreign_key: :nephew_hash, primary_key: true, references: :hash, type: Hash.Full)
    belongs_to(:uncle, Block, foreign_key: :uncle_hash, primary_key: true, references: :hash, type: Hash.Full)
  end

  def changeset(%__MODULE__{} = uncle, params) do
    uncle
    |> cast(params, @allowed_fields)
    |> validate_required(@required_fields)
    |> foreign_key_constraint(:nephew_hash)
    |> unique_constraint(:nephew_hash, name: :uncle_hash_to_nephew_hash)
    |> unique_constraint(:nephew_hash, name: :unfetched_uncles)
    |> unique_constraint(:uncle_hash, name: :nephew_hash_to_uncle_hash)
  end
end
