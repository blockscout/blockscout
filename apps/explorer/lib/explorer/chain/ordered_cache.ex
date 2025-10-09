defmodule Explorer.Chain.OrderedCache do
  @moduledoc """
  Behaviour for a cache of ordered elements.

  A macro based on `ConCache` is provided as well, at its minimum it can be used as;
  ```
  use Explorer.Chain.OrderedCache, name
  ```
  where `name is an `t:atom/0` identifying the cache.

  All default values can be modified by overriding their respective function or
  by setting an option. For example (showing all of them):
  ```
    use Explorer.Chain.OrderedCache,
      name: :name, # need to be set
      max_size: 51, # defaults to 100
      ids_list_key: :ids_key, # defaults to `name`
      preloads: [] # defaults to []
  ```
  Note: `preloads` can also be set singularly with the option `preload`, e.g.:
  ```
    use Explorer.Chain.OrderedCache,
      name: :cache
      preload: :block
      preload: :address
      preload: [transaction: :hash]
  ```
  Additionally all of the options accepted by `ConCache.start_link/1` can be
  provided as well. Unless specified, only these values have defaults:
  - `:ttl_check_interval` is set (to `false`).
  - `:callback` is only set if `:ttl_check_interval` is not `false` to call the
    `remove_deleted_from_index` function, that removes expired values from the index.

  It's also possible, and advised, to override the implementation of the `c:prevails?/2`
  and `c:element_to_id/1` callbacks.
  For typechecking purposes it's also recommended to override the `t:element/0`
  and `t:id/0` type definitions.
  """

  @type element :: struct()

  @type id :: term()

  @doc """
  An atom that identifies this cache
  """
  @callback cache_name :: atom()

  @doc """
  The key used to store the (ordered) list of elements.
  Because this list is stored in the cache itself, one needs to make sure it is
  cannot be equal to any element id.
  """
  @callback ids_list_key :: term()

  @doc """
  The size that this cache cannot exceed.
  """
  @callback max_size :: non_neg_integer()

  @doc """
  Fields of the stored elements that need to be preloaded.
  For entities that are not stored in `Explorer.Repo` this should be empty.
  """
  @callback preloads :: [term()]

  @doc """
  The function that orders the elements and decides the ones that are stored.
  `prevails?(id_a, id_b)` should return `true` if (in case there is no space for both)
  the element with `id_a` should be stored instead of the element with `id_b`,
  `false` otherwise.
  """
  @callback prevails?(id, id) :: boolean()

  @doc """
  The function that obtains an unique `t:id/0` from an `t:element/0`
  """
  @callback element_to_id(element()) :: id()

  @doc "Returns the list ids of the elements currently stored"
  @callback ids_list :: [id]

  @doc """
  Fetches a element from its id, returns nil if not found
  """
  @callback get(id) :: element | nil

  @doc """
  Return the current number of elements stored
  """
  @callback size() :: non_neg_integer()

  @doc """
  Checks if there are enough elements stored
  """
  @callback enough?(non_neg_integer()) :: boolean()

  @doc """
  Checks if the number of elements stored is already the max allowed
  """
  @callback full? :: boolean()

  @doc "Returns all the stored elements"
  @callback all :: [element]

  @doc "Returns the `n` most prevailing elements stored, based on `c:prevails?/2`"
  @callback take(integer()) :: [element]

  @doc """
  Returns the `n` most prevailing elements, based on `c:prevails?/2`, unless there
  are not as many stored, in which case it returns `nil`
  """
  @callback take_enough(integer()) :: [element] | nil

  @doc """
  Behaves like `take_enough/1`, but addresses [#10445](https://github.com/blockscout/blockscout/issues/10445).
  """
  @callback atomic_take_enough(integer()) :: [element] | nil

  @doc """
  Processes the elements before updating the cache.
  This function is called before the `update/1` function and can be used to
  modify the elements to be inserted. Can be used to optimize memory usage along
  with fetching time.
  """
  @callback sanitize_before_update(element) :: element

  @doc """
  Adds an element, or a list of elements, to the cache.
  When the cache is full, only the most prevailing elements will be stored, based
  on `c:prevails?/2`.
  NOTE: every update is isolated from another one.
  """
  @callback update([element] | element | nil) :: :ok

  defmacro __using__(name) when is_atom(name), do: do_using(name, [])

  defmacro __using__(opts) when is_list(opts) do
    # name is necessary
    name = Keyword.fetch!(opts, :name)
    do_using(name, opts)
  end

  # credo:disable-for-next-line /Complexity/
  defp do_using(name, opts) when is_atom(name) and is_list(opts) do
    ids_list_key = Keyword.get(opts, :ids_list_key, name)
    max_size = Keyword.get(opts, :max_size, 100)
    preloads = Keyword.get(opts, :preloads) || Keyword.get_values(opts, :preload)

    concache_params = Keyword.drop(opts, [:ids_list_key, :max_size, :preloads, :preload])

    # credo:disable-for-next-line Credo.Check.Refactor.LongQuoteBlocks
    quote do
      alias Explorer.Chain.OrderedCache

      @behaviour OrderedCache

      ### Automatically set functions

      @impl OrderedCache
      def cache_name, do: unquote(name)

      @impl OrderedCache
      def ids_list_key, do: unquote(ids_list_key)

      @impl OrderedCache
      def max_size, do: unquote(max_size)

      @impl OrderedCache
      def preloads, do: unquote(preloads)

      ### Settable functions

      @impl OrderedCache
      def prevails?(id_a, id_b), do: id_a > id_b

      @impl OrderedCache
      def element_to_id(element), do: element

      @impl OrderedCache
      def sanitize_before_update(element), do: element

      ### Straightforward fetching functions

      @impl OrderedCache
      def ids_list, do: ConCache.get(cache_name(), ids_list_key()) || []

      @impl OrderedCache
      def get(id), do: ConCache.get(cache_name(), id)

      @impl OrderedCache
      def size, do: ids_list() |> Enum.count()

      @impl OrderedCache
      def enough?(amount), do: amount <= size()

      @impl OrderedCache
      def full?, do: max_size() <= size()

      @impl OrderedCache
      def all, do: Enum.map(ids_list(), &get(&1))

      @impl OrderedCache
      def take(amount) do
        ids_list()
        |> Enum.take(amount)
        |> Enum.map(&get(&1))
      end

      @impl OrderedCache
      def take_enough(amount) do
        # behaves just like `if enough?(amount), do: take(amount)` but fetching
        # the list only once
        ids = ids_list()

        if amount <= Enum.count(ids) do
          ids
          |> Enum.take(amount)
          |> Enum.map(&get(&1))
        end
      end

      @impl OrderedCache
      def atomic_take_enough(amount) do
        items =
          cache_name()
          |> ConCache.ets()
          |> :ets.tab2list()

        if amount <= Enum.count(items) - 1 do
          items
          |> Enum.reject(fn {key, _value} -> key == ids_list_key() end)
          |> Enum.sort(&prevails?/2)
          |> Enum.take(amount)
          |> Enum.map(fn {_key, value} -> value end)
        end
      end

      ### Updating function

      def remove_deleted_from_index({:delete, _cache_pid, id}) do
        # simply check with `ConCache.get` because it is faster
        if Enum.member?(ids_list(), id) do
          ConCache.update(cache_name(), ids_list_key(), fn ids ->
            updated_list = List.delete(ids || [], id)
            # ids_list is set to never expire
            {:ok, %ConCache.Item{value: updated_list, ttl: :infinity}}
          end)
        end
      end

      def remove_deleted_from_index(_), do: nil

      @impl OrderedCache
      def update(elements) when is_nil(elements), do: :ok

      def update(elements) when is_list(elements) do
        prepared_elements =
          elements
          |> Enum.sort_by(&element_to_id(&1), &prevails?(&1, &2))
          |> Enum.take(max_size())
          |> do_preloads()
          |> Enum.map(&{element_to_id(&1), sanitize_before_update(&1)})

        ConCache.update(cache_name(), ids_list_key(), fn ids ->
          updated_list =
            prepared_elements
            |> merge_and_update(ids || [], max_size())

          # ids_list is set to never expire
          {:ok, %ConCache.Item{value: updated_list, ttl: :infinity}}
        end)
      end

      def update(element), do: update([element])

      defp do_preloads(elements) do
        if Enum.empty?(preloads()) do
          elements
        else
          Explorer.Repo.preload(elements, preloads())
        end
      end

      defp merge_and_update(_candidates, existing, 0) do
        # if there is no more space in the list remove the remaining existing
        # elements and return an empty list
        remove(existing)
        []
      end

      defp merge_and_update([], existing, size) do
        # if there are no more candidates to be inserted keep as many of the
        # existing elements and remove the rest
        {remaining, to_remove} = Enum.split(existing, size)
        remove(to_remove)
        remaining
      end

      defp merge_and_update(candidates, [], size) do
        # if there are still candidates and no more existing value insert as many
        # candidates as possible and ignore the rest
        candidates
        |> Enum.take(size)
        |> Enum.map(fn {element_id, element} ->
          put_element(element_id, element)
          element_id
        end)
      end

      defp merge_and_update(candidates, existing, size) do
        [{candidate_id, candidate} | to_check] = candidates
        [head | tail] = existing

        cond do
          head == candidate_id ->
            # if a candidate has the id of and existing element, update its value
            put_element(candidate_id, candidate)
            [head | merge_and_update(to_check, tail, size - 1)]

          prevails?(head, candidate_id) ->
            # keep the prevailing existing value and compare all candidates against the rest
            [head | merge_and_update(candidates, tail, size - 1)]

          true ->
            # insert new prevailing candidate and compare the remaining ones with the rest
            put_element(candidate_id, candidate)
            [candidate_id | merge_and_update(to_check, existing, size - 1)]
        end
      end

      defp remove(key) do
        # Always performs async removal so it can wait 1/10 of a second and
        # others have the time to get elements that were in the cache's list.
        # Different updates cannot interfere with the removed element because
        # if this was scheduled for removal it means it is too old, so following
        # updates cannot insert it in the future.
        Task.start_link(fn ->
          Process.sleep(100)

          if is_list(key) do
            Enum.map(key, &ConCache.delete(cache_name(), &1))
          else
            ConCache.delete(cache_name(), key)
          end
        end)
      end

      defp put_element(element_id, element) do
        # dirty puts are a little faster than puts with locks.
        # this is not a problem because this is the only function modifying rows
        # and it only gets called inside `update`, which works isolated
        ConCache.dirty_put(cache_name(), element_id, element)
      end

      ### Supervisor's child specification

      @doc """
      The child specification for a Supervisor. Note that all the `params`
      provided to this function will override the ones set by using the macro
      """
      def child_spec(params) do
        # params specified in `use`
        merged_params =
          unquote(concache_params)
          # params specified in `child_spec`
          |> Keyword.merge(params)
          # `:ttl_check_interval` needs to be specified, defaults to `false`
          |> Keyword.put_new(:ttl_check_interval, false)

        # if `:ttl_check_interval` is not `false` the expired values need to be
        # removed from the cache's index
        params =
          case merged_params[:ttl_check_interval] do
            false -> merged_params
            _ -> Keyword.put_new(merged_params, :callback, &remove_deleted_from_index/1)
          end

        Supervisor.child_spec({ConCache, params}, id: child_id())
      end

      def child_id, do: {ConCache, cache_name()}

      defoverridable cache_name: 0,
                     ids_list_key: 0,
                     max_size: 0,
                     preloads: 0,
                     prevails?: 2,
                     element_to_id: 1,
                     sanitize_before_update: 1
    end
  end
end
