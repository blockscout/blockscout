defmodule Explorer.Chain.Blackfort.Validator do
  @moduledoc """
    Blackfort validators
  """

  use Explorer.Schema

  alias Explorer.Chain.{Address, Import}
  alias Explorer.Chain.Hash.Address, as: HashAddress
  alias Explorer.{Chain, Helper, HttpClient, Repo, SortingHelper}

  require Logger

  @default_sorting [
    asc: :address_hash
  ]

  @primary_key false
  typed_schema "validators_blackfort" do
    field(:address_hash, HashAddress, primary_key: true)
    field(:name, :binary)
    field(:commission, :integer)
    field(:self_bonded_amount, :decimal)
    field(:delegated_amount, :decimal)
    field(:slashing_status_is_slashed, :boolean, default: false)
    field(:slashing_status_by_block, :integer)
    field(:slashing_status_multiplier, :integer)

    has_one(:address, Address, foreign_key: :hash, references: :address_hash)
    timestamps()
  end

  @required_attrs ~w(address_hash)a
  @optional_attrs ~w(name commission self_bonded_amount delegated_amount)a
  def changeset(%__MODULE__{} = validator, attrs) do
    validator
    |> cast(attrs, @required_attrs ++ @optional_attrs)
    |> validate_required(@required_attrs)
    |> unique_constraint(:address_hash)
  end

  @doc """
    Get validators list.
    Keyword could contain:
      - paging_options
      - necessity_by_association
      - sorting (supported by `Explorer.SortingHelper` module)
      - state (one of `@state_enum`)
  """
  @spec get_paginated_validators(keyword()) :: [t()]
  def get_paginated_validators(options \\ []) do
    paging_options = Keyword.get(options, :paging_options, Chain.default_paging_options())
    necessity_by_association = Keyword.get(options, :necessity_by_association, %{})
    sorting = Keyword.get(options, :sorting, [])

    __MODULE__
    |> Chain.join_associations(necessity_by_association)
    |> SortingHelper.apply_sorting(sorting, @default_sorting)
    |> SortingHelper.page_with_sorting(paging_options, sorting, @default_sorting)
    |> Chain.select_repo(options).all()
  end

  @doc """
    Get all validators
  """
  @spec get_all_validators(keyword()) :: [t()]
  def get_all_validators(options \\ []) do
    __MODULE__
    |> Chain.select_repo(options).all()
  end

  @doc """
    Delete validators by address hashes
  """
  @spec delete_validators_by_address_hashes([binary() | HashAddress.t()]) :: {non_neg_integer(), nil | []} | :ignore
  def delete_validators_by_address_hashes(list) when is_list(list) and length(list) > 0 do
    __MODULE__
    |> where([vs], vs.address_hash in ^list)
    |> Repo.delete_all()
  end

  def delete_validators_by_address_hashes(_), do: :ignore

  @doc """
    Insert validators
  """
  @spec insert_validators([map()]) :: {non_neg_integer(), nil | []}
  def insert_validators(validators) do
    Repo.insert_all(__MODULE__, validators,
      on_conflict: {:replace_all_except, [:inserted_at]},
      conflict_target: [:address_hash]
    )
  end

  @doc """
    Append timestamps (:inserted_at, :updated_at)
  """
  @spec append_timestamps(map()) :: map()
  def append_timestamps(validator) do
    Map.merge(validator, Import.timestamps())
  end

  @doc """
    Derive next page params from %Explorer.Chain.Blackfort.Validator{}
  """
  @spec next_page_params(t()) :: map()
  def next_page_params(%__MODULE__{address_hash: address_hash}) do
    %{"address_hash" => address_hash}
  end

  @doc """
    Returns dynamic query for validated blocks count. Needed for SortingHelper
  """
  @spec dynamic_validated_blocks() :: Ecto.Query.dynamic_expr()
  def dynamic_validated_blocks do
    dynamic(
      [vs],
      fragment(
        "SELECT count(*) FROM blocks WHERE miner_hash = ?",
        vs.address_hash
      )
    )
  end

  @doc """
    Returns total count of validators.
  """
  @spec count_validators() :: integer()
  def count_validators do
    Repo.aggregate(__MODULE__, :count, :address_hash)
  end

  @doc """
    Returns count of new validators (inserted withing last 24h).
  """
  @spec count_new_validators() :: integer()
  def count_new_validators do
    __MODULE__
    |> where([vs], vs.inserted_at >= ago(1, "day"))
    |> Repo.aggregate(:count, :address_hash)
  end

  @doc """
    Fetch list of Blackfort validators
  """
  @spec fetch_validators_list() :: {:ok, list()} | :error
  def fetch_validators_list do
    url = validator_url()

    with {:url, true} <- {:url, Helper.valid_url?(url)},
         {:ok, %{status_code: 200, body: body}} <- HttpClient.get(validator_url(), [], follow_redirect: true) do
      body |> Jason.decode() |> parse_validators_info()
    else
      {:url, false} ->
        :error

      error ->
        Logger.error("Failed to fetch blackfort validator info: #{inspect(error)}")
        :error
    end
  end

  defp parse_validators_info({:ok, validators}) do
    {:ok,
     validators
     |> Enum.map(fn %{
                      "address" => address_hash_string,
                      "name" => name,
                      "commission" => commission,
                      "self_bonded_amount" => self_bonded_amount,
                      "delegated_amount" => delegated_amount,
                      "slashing_status" => %{
                        "is_slashed" => slashing_status_is_slashed,
                        "by_block" => slashing_status_by_block,
                        "multiplier" => slashing_status_multiplier
                      }
                    } ->
       {:ok, address_hash} = HashAddress.cast(address_hash_string)

       %{
         address_hash: address_hash,
         name: name,
         commission: parse_number(commission),
         self_bonded_amount: parse_number(self_bonded_amount),
         delegated_amount: parse_number(delegated_amount),
         slashing_status_is_slashed: slashing_status_is_slashed,
         slashing_status_by_block: slashing_status_by_block,
         slashing_status_multiplier: slashing_status_multiplier
       }
     end)}
  end

  defp parse_validators_info({:error, error}) do
    Logger.error("Failed to parse blackfort validator info: #{inspect(error)}")
    :error
  end

  defp validator_url do
    Application.get_env(:explorer, __MODULE__)[:api_url]
  end

  defp parse_number(string) do
    {number, _} = Integer.parse(string)
    number
  end
end
