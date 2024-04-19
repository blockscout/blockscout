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
  * `address_hash` - implementation `smart_contract` address hash. Proxy can contain multiple implementations at once.
  * `name` - name of the proxy implementation.
  """
  typed_schema "proxy_implementations" do
    field(:proxy_address_hash, Hash.Address, null: false)
    field(:address_hash, Hash.Address, null: false)
    field(:name, :string, null: true)

    timestamps()
  end

  def changeset(%__MODULE__{} = proxy_implementation, attrs) do
    proxy_implementation
    |> cast(attrs, [
      :proxy_address_hash,
      :address_hash
    ])
    |> validate_required([:proxy_address_hash, :address_hash])
    |> unique_constraint([:proxy_address_hash, :address_hash])
  end

  @doc """
  Returns all implementations for the given smart-contract address hash
  """
  @spec get_proxy_implementations(SmartContract.t() | nil, Keyword.t()) :: [__MODULE__.t()]
  def get_proxy_implementations(address_hash, options) do
    all_implementations_query =
      from(
        p in __MODULE__,
        where: p.proxy_address_hash == ^address_hash,
        select: p.address_hash
      )

    all_implementations_query
    |> select_repo(options).all()
  end

  @doc """
  Returns a single implementation for the given smart-contract address hash
  """
  @spec get_proxy_implementation(SmartContract.t() | nil, Keyword.t()) :: [__MODULE__.t()]
  def get_proxy_implementation(address_hash, options) do
    all_implementations_query =
      from(
        p in __MODULE__,
        where: p.proxy_address_hash == ^address_hash,
        select: p.address_hash,
        limit: 1
      )

    all_implementations_query
    |> select_repo(options).all()
  end

  @doc """
  Returns all implementations for the given smart-contract address hash
  """
  @spec get_proxy_implementation_updated_at(Hash.Address.t() | nil, Keyword.t()) :: DateTime.t()
  def get_proxy_implementation_updated_at(address_hash, options) do
    max_updated_at_query =
      from(
        p in __MODULE__,
        where: p.proxy_address_hash == ^address_hash,
        select: max(p.updated_at)
      )

    max_updated_at_query
    |> select_repo(options).all()
  end

  @doc """
  Returns implementation address and name of the given SmartContract by hash address
  """
  @spec get_implementation_address_hash(any(), any()) :: {any(), any()}
  def get_implementation_address_hash(smart_contract, options \\ [])

  def get_implementation_address_hash(%SmartContract{abi: nil}, _), do: {nil, nil}

  def get_implementation_address_hash(%SmartContract{metadata_from_verified_twin: true} = smart_contract, options) do
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
        SmartContract.address_hash_to_smart_contract_without_twin(address_hash, options)
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
           metadata_from_verified_twin: metadata_from_verified_twin
         }},
        options
      ) do
    implementation_updated_at = get_proxy_implementation_updated_at(address_hash, options)

    proxy_implementations = get_proxy_implementations(address_hash, options)

    # todo: process multiple implementations in case of Diamond proxy
    {implementation_address_hash_from_db, implementation_name_from_db} =
      if Enum.count(proxy_implementations) == 1 do
        implementation = proxy_implementations |> Enum.at(0)

        {implementation.address_hash, implementation.name}
      else
        {nil, nil}
      end

    if check_implementation_refetch_necessity(implementation_updated_at) do
      get_implementation_address_hash_task =
        Task.async(fn ->
          result = Proxy.fetch_implementation_address_hash(address_hash, abi, metadata_from_verified_twin, options)
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
  Saves proxy implementation into the DB
  """
  @spec save_implementation_data(String.t() | nil, Hash.Address.t(), boolean(), Keyword.t()) ::
          {nil, nil} | {String.t(), String.t() | nil}
  def save_implementation_data(nil, _, _, _), do: {nil, nil}

  def save_implementation_data(empty_address_hash_string, proxy_address_hash, metadata_from_verified_twin, options)
      when is_burn_signature(empty_address_hash_string) do
    if is_nil(metadata_from_verified_twin) or !metadata_from_verified_twin do
      proxy_implementations = get_proxy_implementations(proxy_address_hash, options)

      # todo: process multiple implementations in case of Diamond proxy
      if Enum.count(proxy_implementations) == 1 do
        proxy_implementations
        |> Enum.at(0)
        |> changeset(%{
          name: nil,
          address_hash: nil
        })
        |> Repo.update()
      end
    end

    {:empty, :empty}
  end

  def save_implementation_data(implementation_address_hash_string, proxy_address_hash, _, options)
      when is_binary(implementation_address_hash_string) do
    with {:ok, address_hash} <- string_to_address_hash(implementation_address_hash_string),
         proxy_implementations <- get_proxy_implementations(proxy_address_hash, options),
         # todo: process multiple implementations in case of Diamond proxy
         1 <- Enum.count(proxy_implementations),
         implementation <- proxy_implementations |> Enum.at(0),
         false <- is_nil(implementation),
         %SmartContract{name: name} <- SmartContract.address_hash_to_smart_contract(address_hash, options) do
      implementation
      |> changeset(%{
        name: name,
        address_hash: implementation_address_hash_string
      })
      |> Repo.update()

      {implementation_address_hash_string, name}
    else
      %{implementation: _, proxy: proxy_contract} ->
        proxy_implementations = get_proxy_implementations(proxy_contract.address_hash, options)
        # todo: process multiple implementations in case of Diamond proxy
        if Enum.count(proxy_implementations) == 1 do
          implementation = proxy_implementations |> Enum.at(0)

          implementation
          |> changeset(%{
            name: nil,
            address_hash: implementation_address_hash_string
          })
          |> Repo.update()
        end

        {implementation_address_hash_string, nil}

      true ->
        {:ok, address_hash} = string_to_address_hash(implementation_address_hash_string)
        smart_contract = SmartContract.address_hash_to_smart_contract(address_hash, options)

        {implementation_address_hash_string, smart_contract && smart_contract.name}

      _ ->
        {implementation_address_hash_string, nil}
    end
  end

  defp db_implementation_data_converter(nil), do: nil
  defp db_implementation_data_converter(string) when is_binary(string), do: string
  defp db_implementation_data_converter(other), do: to_string(other)

  @doc """
  Returns proxy's implementation name
  """
  @spec name(Address.t() | nil) :: String.t() | nil
  def name(_proxy_address_hash, options \\ [])

  def name(proxy_address_hash, options) when not is_nil(proxy_address_hash) do
    proxy_implementations = get_proxy_implementations(proxy_address_hash, options)

    # todo: process multiple implementations in case of Diamond proxy
    if Enum.count(proxy_implementations) == 1 do
      implementation = proxy_implementations |> Enum.at(0)
      implementation.name
    else
      nil
    end
  end

  def name(_, _), do: nil
end
