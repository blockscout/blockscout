defmodule Explorer.Chain.SmartContract.Proxy.Models.Implementation do
  @moduledoc """
  The representation of proxy smart-contract implementation.
  """

  require Logger

  use Explorer.Schema
  use Utils.CompileTimeEnvHelper, chain_type: [:explorer, :chain_type]

  import Ecto.Query,
    only: [
      from: 2,
      select: 3
    ]

  alias Explorer.{Chain, Repo}
  alias Explorer.Chain.{Address, Hash, SmartContract}
  alias Explorer.Chain.SmartContract.Proxy
  alias Explorer.Counters.AverageBlockTime
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

    # the order matches order of enum values in the DB
    field(:proxy_type, Ecto.Enum,
      values: [
        :eip1167,
        :eip1967,
        :eip1822,
        :eip930,
        :master_copy,
        :basic_implementation,
        :basic_get_implementation,
        :comptroller,
        :eip2535,
        :clone_with_immutable_arguments,
        :eip7702,
        :unknown
      ],
      null: true
    )

    field(:address_hashes, {:array, Hash.Address}, null: false)
    field(:names, {:array, :string}, null: false)

    has_many(:addresses, Address, foreign_key: :hash, references: :address_hashes)

    belongs_to(
      :address,
      Address,
      foreign_key: :proxy_address_hash,
      references: :hash,
      define_field: false
    )

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
  def get_proxy_implementations(proxy_address_hash, options \\ []) do
    proxy_address_hash
    |> get_proxy_implementations_query()
    |> Chain.select_repo(options).one()
  end

  @doc """
  Returns all implementations for the given smart-contract address hashes
  """
  @spec get_proxy_implementations_for_multiple_proxies([Hash.Address.t()], Keyword.t()) :: [__MODULE__.t()]
  def get_proxy_implementations_for_multiple_proxies(proxy_address_hashes, options \\ [])

  def get_proxy_implementations_for_multiple_proxies([], _), do: []

  def get_proxy_implementations_for_multiple_proxies(proxy_address_hashes, options) do
    proxy_address_hashes
    |> get_proxy_implementations_by_multiple_hashes_query()
    |> Chain.select_repo(options).all()
  end

  @doc """
  Returns the last implementation updated_at for the given smart-contract address hash
  """
  @spec get_proxy_implementation_updated_at(Hash.Address.t() | nil, Keyword.t()) :: DateTime.t() | nil
  def get_proxy_implementation_updated_at(proxy_address_hash, options) do
    proxy_address_hash
    |> get_proxy_implementations_query()
    |> select([p], p.updated_at)
    |> Chain.select_repo(options).one()
  end

  defp get_proxy_implementations_query(proxy_address_hash) do
    from(
      p in __MODULE__,
      where: p.proxy_address_hash == ^proxy_address_hash
    )
  end

  defp get_proxy_implementations_by_multiple_hashes_query(proxy_address_hashes) do
    from(
      p in __MODULE__,
      where: p.proxy_address_hash in ^proxy_address_hashes
    )
  end

  @doc """
  Returns implementation address, name and proxy type for the given SmartContract
  """
  @spec get_implementation(any(), any()) :: t() | nil
  def get_implementation(smart_contract, options \\ [])

  def get_implementation(
        %SmartContract{metadata_from_verified_bytecode_twin: true} = smart_contract,
        options
      ) do
    get_implementation(
      %{
        updated: smart_contract,
        implementation_updated_at: nil,
        implementation_address_fetched?: false,
        refetch_necessity_checked?: false
      },
      options
    )
  end

  def get_implementation(
        %SmartContract{
          address_hash: address_hash
        } = smart_contract,
        options
      ) do
    implementation_updated_at = get_proxy_implementation_updated_at(address_hash, options)

    {updated_smart_contract, implementation_address_fetched?} =
      if check_implementation_refetch_necessity(implementation_updated_at) do
        {smart_contract_with_bytecode_twin, implementation_address_fetched?} =
          SmartContract.address_hash_to_smart_contract_with_bytecode_twin(address_hash, options)

        if smart_contract_with_bytecode_twin do
          {smart_contract_with_bytecode_twin, implementation_address_fetched?}
        else
          {smart_contract, implementation_address_fetched?}
        end
      else
        if implementation_updated_at do
          {smart_contract, true}
        else
          {smart_contract, false}
        end
      end

    get_implementation(
      %{
        updated: updated_smart_contract,
        implementation_updated_at: implementation_updated_at,
        implementation_address_fetched?: implementation_address_fetched?,
        refetch_necessity_checked?: true
      },
      options
    )
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  def get_implementation(
        %{
          updated: %SmartContract{
            address_hash: address_hash,
            abi: abi
          },
          implementation_updated_at: implementation_updated_at,
          implementation_address_fetched?: implementation_address_fetched?,
          refetch_necessity_checked?: refetch_necessity_checked?
        },
        options
      ) do
    proxy_implementations = get_proxy_implementations(address_hash, options)

    implementation_updated_at = implementation_updated_at || (proxy_implementations && proxy_implementations.updated_at)

    if fetch_implementation?(implementation_address_fetched?, refetch_necessity_checked?, implementation_updated_at) do
      get_implementation_address_hash_task =
        Task.async(fn ->
          # Here and only here we fetch implementations for the given address
          # using requests to the JSON RPC node for known proxy patterns
          result = Proxy.fetch_implementation_address_hash(address_hash, abi, options)

          callback = Keyword.get(options, :callback, nil)
          uid = Keyword.get(options, :uid)

          callback && callback.(result, uid)

          result
        end)

      timeout =
        Keyword.get(options, :timeout, Application.get_env(:explorer, :proxy)[:implementation_data_fetching_timeout])

      case Task.yield(get_implementation_address_hash_task, timeout) ||
             Task.ignore(get_implementation_address_hash_task) do
        {:ok, :empty} ->
          nil

        {:ok, :error} ->
          proxy_implementations

        {:ok, %__MODULE__{} = result} ->
          result

        _ ->
          proxy_implementations
      end
    else
      proxy_implementations
    end
  end

  def get_implementation(_, _), do: nil

  defp fetch_implementation?(implementation_address_fetched?, refetch_necessity_checked?, implementation_updated_at) do
    (!implementation_address_fetched? || !refetch_necessity_checked?) &&
      check_implementation_refetch_necessity(implementation_updated_at)
  end

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
  @spec save_implementation_data([String.t()], Hash.Address.t(), atom() | nil, Keyword.t()) ::
          __MODULE__.t() | :empty | :error
  def save_implementation_data(:error, _proxy_address_hash, _proxy_type, _options) do
    :error
  end

  def save_implementation_data(implementation_address_hash_strings, proxy_address_hash, proxy_type, options)
      when is_nil(implementation_address_hash_strings) or
             implementation_address_hash_strings == [] do
    upsert_implementation(proxy_address_hash, proxy_type, [], [], options)

    :empty
  end

  def save_implementation_data(
        [empty_implementation_address_hash_string],
        proxy_address_hash,
        proxy_type,
        options
      )
      when is_burn_signature(empty_implementation_address_hash_string) do
    upsert_implementation(proxy_address_hash, proxy_type, [], [], options)

    :empty
  end

  def save_implementation_data(
        implementation_address_hash_strings,
        proxy_address_hash,
        proxy_type,
        options
      ) do
    {implementation_addresses, implementation_names} =
      implementation_address_hash_strings
      |> Enum.map(fn implementation_address_hash_string ->
        with {:ok, implementation_address_hash} <- Chain.string_to_address_hash(implementation_address_hash_string),
             {:implementation, {%SmartContract{name: name}, _}} <- {
               :implementation,
               SmartContract.address_hash_to_smart_contract_with_bytecode_twin(implementation_address_hash, options)
             } do
          {implementation_address_hash_string, name}
        else
          :error ->
            :error

          {:implementation, _} ->
            {implementation_address_hash_string, nil}
        end
      end)
      |> Enum.filter(&(&1 !== :error))
      |> Enum.unzip()

    if Enum.empty?(implementation_addresses) do
      :empty
    else
      case upsert_implementation(
             proxy_address_hash,
             proxy_type,
             implementation_addresses,
             implementation_names,
             options
           ) do
        {:ok, result} ->
          result

        {:error, error} ->
          Logger.error("Error while upserting proxy implementations data into the DB: #{inspect(error)}")
          :error
      end
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
      address_hashes: implementation_address_hash_strings,
      names: names
    }

    %__MODULE__{}
    |> changeset(changeset)
    |> Repo.insert()
  end

  defp update_implementation(proxy, proxy_type, implementation_address_hash_strings, names) do
    proxy
    |> changeset(%{
      proxy_type: proxy_type,
      address_hashes: implementation_address_hash_strings,
      names: names
    })
    |> Repo.update()
  end

  @doc """
  Returns proxy's implementation names
  """
  @spec names(Address.t() | nil) :: String.t() | [String.t()]
  def names(_proxy_address, options \\ [])

  def names(proxy_address, options) when not is_nil(proxy_address) do
    proxy_implementations = get_proxy_implementations(proxy_address.hash, options)

    if proxy_implementations && not Enum.empty?(proxy_implementations.names) do
      proxy_implementations.names
    else
      []
    end
  end

  def names(_, _), do: []

  if @chain_type == :filecoin do
    @doc """
    Fetches associated addresses for Filecoin based on the provided nested IDs.

    This function is used in Ecto preload to retrieve addresses for proxy implementations.

    ## Parameters

      - nested_ids: A list of nested IDs for which the associated addresses need to be fetched.

    ## Returns

      - A list of associated addresses for the given nested IDs.
    """
    def addresses_association_for_filecoin(nested_ids) do
      query = from(address in Address, where: address.hash in ^List.flatten(nested_ids))

      addresses_map =
        query
        |> Repo.replica().all()
        |> Map.new(&{&1.hash, &1})

      for ids <- nested_ids,
          address <- ids |> Enum.map(&addresses_map[&1]) do
        {ids, address}
      end
    end

    @doc """
    Returns the association for proxy implementations.

    This function is used to retrieve the proxy_implementations associations for address

    ## Examples

      iex> Explorer.Chain.SmartContract.Proxy.Models.Implementation.proxy_implementations_association()
      [proxy_implementations: [addresses: &Explorer.Chain.SmartContract.Proxy.Models.Implementation.addresses_association_for_filecoin/1]]
    """
    @spec proxy_implementations_association() :: [
            proxy_implementations: [addresses: fun()]
          ]
    def proxy_implementations_association do
      [proxy_implementations: proxy_implementations_addresses_association()]
    end

    @doc """
    Returns the association of proxy implementation addresses.

    This function is used to retrieve the addresses associations for proxy

    ## Examples

      iex> Explorer.Chain.SmartContract.Proxy.Models.Implementation.proxy_implementations_addresses_association()
      [addresses: &Explorer.Chain.SmartContract.Proxy.Models.Implementation.addresses_association_for_filecoin/1]

    """
    @spec proxy_implementations_association() :: [addresses: fun()]
    def proxy_implementations_addresses_association do
      [addresses: &__MODULE__.addresses_association_for_filecoin/1]
    end
  else
    @doc """
    Returns the association for proxy implementations.

    This function is used to retrieve the proxy_implementations associations for address

    ## Examples

      iex> Explorer.Chain.SmartContract.Proxy.Models.Implementation.proxy_implementations_association()
      :proxy_implementations

    """
    @spec proxy_implementations_association() :: :proxy_implementations
    def proxy_implementations_association do
      :proxy_implementations
    end

    @doc """
    Returns the association of proxy implementation addresses.

    This function is used to retrieve the addresses associations for proxy.
    (Returns [] since in chain types other than Filecoin, the addresses are not needed to preload)

    ## Examples

      iex> Explorer.Chain.SmartContract.Proxy.Models.Implementation.proxy_implementations_addresses_association()
      []

    """
    @spec proxy_implementations_addresses_association() :: []
    def proxy_implementations_addresses_association do
      []
    end
  end
end
