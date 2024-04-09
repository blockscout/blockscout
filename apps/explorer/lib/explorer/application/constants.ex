defmodule Explorer.Application.Constants do
  @moduledoc """
    Tracks some kv info
  """

  use Explorer.Schema
  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.Hash

  @keys_manager_contract_address_key "keys_manager_contract_address"
  @last_processed_erc_721_token "token_instance_sanitizer_last_processed_erc_721_token"

  @primary_key false
  typed_schema "constants" do
    field(:key, :string, primary_key: true, null: false)
    field(:value, :string, null: false)

    timestamps()
  end

  def changeset(attrs) do
    %__MODULE__{}
    |> changeset(attrs)
  end

  @required_attrs ~w(key value)a
  def changeset(%__MODULE__{} = constant, attrs) do
    constant
    |> cast(attrs, @required_attrs)
    |> validate_required(@required_attrs)
  end

  def get_constant_by_key(key, options \\ []) do
    __MODULE__
    |> where([constant], constant.key == ^key)
    |> Chain.select_repo(options).one()
  end

  def get_constant_value(key, options \\ []) do
    __MODULE__
    |> where([constant], constant.key == ^key)
    |> select([constant], constant.value)
    |> Chain.select_repo(options).one()
  end

  def set_constant_value(key, value) do
    existing_value = Repo.get(__MODULE__, key)

    if existing_value do
      existing_value
      |> changeset(%{value: value})
      |> Repo.update!()
    else
      %{key: key, value: value}
      |> changeset()
      |> Repo.insert!()
    end
  end

  def insert_keys_manager_contract_address(value) do
    %{key: @keys_manager_contract_address_key, value: value}
    |> changeset()
    |> Repo.insert!()
  end

  def get_keys_manager_contract_address(options \\ []) do
    get_constant_by_key(@keys_manager_contract_address_key, options)
  end

  @doc """
    For usage in Indexer.Fetcher.TokenInstance.SanitizeERC721
  """
  @spec insert_last_processed_token_address_hash(Hash.Address.t()) :: Ecto.Schema.t()
  def insert_last_processed_token_address_hash(address_hash) do
    set_constant_value(@last_processed_erc_721_token, to_string(address_hash))
  end

  @doc """
    For usage in Indexer.Fetcher.TokenInstance.SanitizeERC721
  """
  @spec get_last_processed_token_address_hash(keyword()) :: nil | Explorer.Chain.Hash.t()
  def get_last_processed_token_address_hash(options \\ []) do
    result = get_constant_by_key(@last_processed_erc_721_token, options)

    case Chain.string_to_address_hash(result) do
      {:ok, address_hash} ->
        address_hash

      _ ->
        nil
    end
  end
end
