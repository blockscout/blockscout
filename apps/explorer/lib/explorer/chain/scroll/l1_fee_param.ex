defmodule Explorer.Chain.Scroll.L1FeeParam do
  @moduledoc "Models an L1 fee parameter for Scroll."

  use Explorer.Schema

  import Explorer.Chain, only: [select_repo: 1]

  @required_attrs ~w(block_number tx_index name value)a

  @typedoc """
    * `block_number` - A block number of the transaction where the given parameter was changed.
    * `tx_index` - An index of the transaction (within the block) where the given parameter was changed.
    * `name` - A name of the parameter (can be `overhead` or `scalar`).
    * `value` - A new value of the parameter.
  """
  @primary_key false
  typed_schema "scroll_l1_fee_params" do
    field(:block_number, :integer, primary_key: true)
    field(:tx_index, :integer, primary_key: true)
    field(:name, Ecto.Enum, values: [:overhead, :scalar], primary_key: true)
    field(:value, :integer)

    timestamps()
  end

  def changeset(%__MODULE__{} = params, attrs \\ %{}) do
    params
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint([:block_number, :tx_index])
  end

  def get_for_transaction(name, transaction, options \\ []) when name in [:overhead, :scalar] do
    query =
      from(p in __MODULE__,
        select: p.value,
        where:
          p.name == ^name and
            (p.block_number < ^transaction.block_number or
               (p.block_number == ^transaction.block_number and p.tx_index < ^transaction.index)),
        order_by: [desc: p.block_number, desc: p.tx_index],
        limit: 1
      )

    select_repo(options).one(query) || 0
  end

  def l1_gas_used(transaction, l1_fee_overhead) do
    if transaction.block_number > Application.get_all_env(:indexer)[Indexer.Fetcher.Scroll.L1FeeParam][:curie_upgrade_block] do
      0
    else
      total =
        transaction.input.bytes
        |> :binary.bin_to_list()
        |> Enum.reduce(0, fn byte, acc ->
          if byte == 0 do
            acc + 4
          else
            acc + 16
          end
        end)

      total + l1_fee_overhead + 4 * 16
    end
  end
end
