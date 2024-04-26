defmodule Explorer.Chain.SmartContract.Proxy.Models.Implementation do
  @moduledoc """
  The representation of proxy smart-contract implementation.
  """

  require Logger

  use Explorer.Schema

  import Explorer.Chain, only: [select_repo: 1, string_to_address_hash: 1]

  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Counters.AverageBlockTime
  alias Explorer.Repo
  alias Timex.Duration

  @burn_address_hash_string "0x0000000000000000000000000000000000000000"
  @burn_address_hash_string_32 "0x0000000000000000000000000000000000000000000000000000000000000000"

  defguard is_burn_signature(term) when term in ["0x", "0x0", @burn_address_hash_string, @burn_address_hash_string_32]

  @typedoc """
  * `proxy_address_hash` - proxy `smart_contract` address hash.
  * `proxy_type` - type of the proxy.
  * `address_hashes` - array of implementation `smart_contract` address hashes. Proxy can contain multiple implementations at once.
  * `names` - array of implementation `smart_contract` names.
  """
  @primary_key false
  typed_schema "proxy_implementations" do
    field(:proxy_address_hash, Hash.Address, primary_key: true, null: false)

    field(:proxy_type, Ecto.Enum,
      values: [
        :eip1167,
        :eip1967,
        :eip1822,
        :eip930,
        :eip2535,
        :master_copy,
        :basic_implementation,
        :basic_get_implementation,
        :comptroller,
        :unknown
      ],
      null: true
    )

    field(:address_hashes, {:array, Hash.Address}, null: false)
    field(:names, {:array, :string}, null: false)

    timestamps()
  end

  def changeset(%__MODULE__{} = proxy_implementation, attrs) do
    proxy_implementation
    |> cast(attrs, [
      :proxy_address_hash,
      :proxy_type,
      :address_hashes,
      :names
    ])
    |> validate_required([:proxy_address_hash, :proxy_type, :address_hashes, :names])
    |> unique_constraint([:proxy_address_hash])
  end

  @doc """
  Returns all implementations for the given smart-contract address hash
  """
  @spec get_proxy_implementations(Hash.Address.t() | nil, Keyword.t()) :: __MODULE__.t() | nil
  def get_proxy_implementations(address_hash, options \\ []) do
    all_implementations_query =
      from(
        p in __MODULE__,
        where: p.proxy_address_hash == ^address_hash
      )

    all_implementations_query
    |> select_repo(options).one()
  end

  @doc """
  Returns the last implementation updated_at for the given smart-contract address hash
  """
  @spec get_proxy_implementation_updated_at(Hash.Address.t() | nil, Keyword.t()) :: DateTime.t()
  def get_proxy_implementation_updated_at(address_hash, options) do
    max_updated_at_query =
      from(
        p in __MODULE__,
        where: p.proxy_address_hash == ^address_hash,
        select: p.updated_at
      )

    max_updated_at_query
    |> select_repo(options).one()
  end

  @doc """
  Returns implementation address and name of the given SmartContract by hash address
  """
  @spec get_implementation_address_hash(any(), any()) :: {any(), any()}
  def get_implementation_address_hash(smart_contract, options \\ [])

  def get_implementation_address_hash(
        %SmartContract{metadata_from_verified_bytecode_twin: true} = smart_contract,
        options
      ) do
    get_implementation_address_hash({:updated, smart_contract}, options)
  end

  def get_implementation_address_hash(
        %SmartContract{
          address_hash: address_hash
        } = smart_contract,
        options
      ) do
    implementation_updated_at = get_proxy_implementation_updated_at(address_hash, options)

    updated_smart_contract =
      if Application.get_env(:explorer, :proxy)[:caching_implementation_data_enabled] &&
           check_implementation_refetch_necessity(implementation_updated_at) do
        SmartContract.address_hash_to_smart_contract_with_bytecode_twin(address_hash, options)
      else
        smart_contract
      end

    get_implementation_address_hash({:updated, updated_smart_contract}, options)
  end

  def get_implementation_address_hash(
        {:updated,
         %SmartContract{
           address_hash: address_hash,
           abi: abi,
           metadata_from_verified_bytecode_twin: metadata_from_verified_bytecode_twin
         }},
        options
      ) do
    implementation_updated_at = get_proxy_implementation_updated_at(address_hash, options)

    proxy_implementations = get_proxy_implementations(address_hash, options)

    {implementation_address_hash_from_db, implementation_name_from_db} =
      if proxy_implementations do
        {proxy_implementations.address_hashes, proxy_implementations.names}
      else
        {nil, nil}
      end

    if check_implementation_refetch_necessity(implementation_updated_at) do
      get_implementation_address_hash_task =
        Task.async(fn ->
          result =
            Proxy.fetch_implementation_address_hash(address_hash, abi, metadata_from_verified_bytecode_twin, options)

          callback = Keyword.get(options, :callback, nil)
          uid = Keyword.get(options, :uid)

          callback && callback.(result, uid)

          result
        end)

      timeout =
        Keyword.get(options, :timeout, Application.get_env(:explorer, :proxy)[:implementation_data_fetching_timeout])

      case Task.yield(get_implementation_address_hash_task, timeout) ||
             Task.ignore(get_implementation_address_hash_task) do
        {:ok, {:empty, :empty}} ->
          {nil, nil}

        {:ok, {address_hash, _name} = result} when not is_nil(address_hash) ->
          result

        _ ->
          {db_implementation_data_converter(implementation_address_hash_from_db),
           db_implementation_data_converter(implementation_name_from_db)}
      end
    else
      {db_implementation_data_converter(implementation_address_hash_from_db),
       db_implementation_data_converter(implementation_name_from_db)}
    end
  end

  def get_implementation_address_hash(_, _), do: {nil, nil}

  @doc """
    Function checks by timestamp if new implementation fetching needed
  """
  @spec check_implementation_refetch_necessity(Calendar.datetime() | nil) :: boolean()
  def check_implementation_refetch_necessity(nil), do: true

  def check_implementation_refetch_necessity(timestamp) do
    if Application.get_env(:explorer, :proxy)[:caching_implementation_data_enabled] do
      now = DateTime.utc_now()

      fresh_time_distance = get_fresh_time_distance()

      timestamp
      |> DateTime.add(fresh_time_distance, :millisecond)
      |> DateTime.compare(now) != :gt
    else
      true
    end
  end

  @doc """
    Returns time interval in milliseconds in which fetched proxy info is not needed to be refetched
  """
  @spec get_fresh_time_distance() :: integer()
  def get_fresh_time_distance do
    average_block_time = get_average_block_time_for_implementation_refetch()

    case average_block_time do
      0 ->
        Application.get_env(:explorer, :proxy)[:fallback_cached_implementation_data_ttl]

      time ->
        round(time)
    end
  end

  defp get_average_block_time_for_implementation_refetch do
    if Application.get_env(:explorer, :proxy)[:implementation_data_ttl_via_avg_block_time] do
      case AverageBlockTime.average_block_time() do
        {:error, :disabled} ->
          0

        duration ->
          duration
          |> Duration.to_milliseconds()
      end
    else
      0
    end
  end

  @doc """
  Saves proxy's implementation into the DB
  """
  @spec save_implementation_data(
          [String.t()] | nil,
          [String.t()] | nil,
          Hash.Address.t(),
          atom() | nil,
          boolean(),
          Keyword.t()
        ) ::
          {nil, nil} | {[String.t()], [String.t()]}
  def save_implementation_data(nil, _, proxy_address_hash, proxy_type, metadata_from_verified_bytecode_twin, options) do
    if is_nil(metadata_from_verified_bytecode_twin) or !metadata_from_verified_bytecode_twin do
      upsert_implementation(proxy_address_hash, proxy_type, nil, nil, options)
    end

    {:empty, :empty}
  end

  def save_implementation_data(
        [empty_implementation_address_hash_string],
        _,
        proxy_address_hash,
        proxy_type,
        metadata_from_verified_bytecode_twin,
        options
      )
      when is_burn_signature(empty_implementation_address_hash_string) do
    if is_nil(metadata_from_verified_bytecode_twin) or !metadata_from_verified_bytecode_twin do
      upsert_implementation(proxy_address_hash, proxy_type, nil, nil, options)
    end

    {:empty, :empty}
  end

  def save_implementation_data(
        [],
        _,
        proxy_address_hash,
        proxy_type,
        metadata_from_verified_bytecode_twin,
        options
      ) do
    if is_nil(metadata_from_verified_bytecode_twin) or !metadata_from_verified_bytecode_twin do
      upsert_implementation(proxy_address_hash, proxy_type, nil, nil, options)
    end

    {:empty, :empty}
  end

  def save_implementation_data(
        implementation_address_hash_strings,
        implementation_names,
        proxy_address_hash,
        proxy_type,
        _,
        options
      ) do
    raw_implementations = Enum.zip(implementation_address_hash_strings, implementation_names)

    implementations =
      raw_implementations
      |> Enum.map(fn {implementation_address_hash_string, implementation_name} ->
        with {:ok, implementation_address_hash} <- string_to_address_hash(implementation_address_hash_string),
             proxy_contract <- SmartContract.address_hash_to_smart_contract(proxy_address_hash, options),
             {:smart_contract_exists, true, implementation_address_hash} <-
               {:smart_contract_exists, not is_nil(proxy_contract), implementation_address_hash},
             %{implementation: %SmartContract{name: name}, proxy: _proxy_contract} <- %{
               implementation:
                 SmartContract.address_hash_to_smart_contract_with_bytecode_twin(implementation_address_hash, options),
               proxy: proxy_contract
             } do
          {implementation_address_hash_string, name}
        else
          :error ->
            :error

          {:smart_contract_exists, false, implementation_address_hash} ->
            smart_contract =
              SmartContract.address_hash_to_smart_contract_with_bytecode_twin(implementation_address_hash, options)

            implementation_name = implementation_name || (smart_contract && smart_contract.name) || nil

            {implementation_address_hash_string, implementation_name}

          %{implementation: _, proxy: _} ->
            {implementation_address_hash_string, nil}
        end
      end)
      |> Enum.filter(&(&1 !== :error))

    if Enum.empty?(implementations) do
      {:empty, :empty}
    else
      upsert_implementation(
        proxy_address_hash,
        proxy_type,
        implementation_address_hash_strings,
        implementation_names,
        options
      )

      {implementation_address_hash_strings, implementation_names}
    end
  end

  defp upsert_implementation(proxy_address_hash, proxy_type, implementation_address_hash_strings, names, options) do
    proxy = get_proxy_implementations(proxy_address_hash, options)

    if proxy do
      update_implementation(proxy, proxy_type, implementation_address_hash_strings, names)
    else
      insert_implementation(proxy_address_hash, proxy_type, implementation_address_hash_strings, names)
    end
  end

  defp insert_implementation(proxy_address_hash, proxy_type, implementation_address_hash_strings, names)
       when not is_nil(proxy_address_hash) do
    changeset = %{
      proxy_address_hash: proxy_address_hash,
      proxy_type: proxy_type,
      address_hashes: prepare_value(implementation_address_hash_strings),
      names: prepare_value(names)
    }

    %__MODULE__{}
    |> changeset(changeset)
    |> Repo.insert()
  end

  defp update_implementation(proxy, proxy_type, implementation_address_hash_strings, names) do
    proxy
    |> changeset(%{
      proxy_type: proxy_type,
      address_hashes: prepare_value(implementation_address_hash_strings),
      names: prepare_value(names)
    })
    |> Repo.update()
  end

  defp prepare_value(value) when is_list(value) do
    value
  end

  defp prepare_value(value) do
    (value && [value]) || []
  end

  defp db_implementation_data_converter(nil), do: nil

  defp db_implementation_data_converter(list) when is_list(list),
    do: list |> Enum.map(&db_implementation_data_converter(&1))

  defp db_implementation_data_converter(string) when is_binary(string), do: string
  defp db_implementation_data_converter(other), do: to_string(other)

  @doc """
  Returns proxy's implementation name
  """
  @spec name(Address.t() | nil) :: String.t() | nil
  def name(_proxy_address, options \\ [])

  def name(proxy_address, options) when not is_nil(proxy_address) do
    proxy_implementations = get_proxy_implementations(proxy_address.hash, options)

    if proxy_implementations && not Enum.empty?(proxy_implementations.names) do
      proxy_implementations.names
    else
      nil
    end
  end

  def name(_, _), do: nil
end
