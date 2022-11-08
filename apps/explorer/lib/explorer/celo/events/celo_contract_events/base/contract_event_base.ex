defmodule Explorer.Celo.ContractEvents.Base do
  @moduledoc """
    Defines and generates functionality for Celo contract event structs.

    After calling `use Explorer.Celo.ContractEvents.Base` and providing event name and topic, event parameters are set
    with the `event_param` macro. This information is then used to generate the rest of the functionality for the event.

    # Generated Properties

    The following functionality is generated for a specific event

    * A struct is created giving the object properties defined in the event parameters
    * An implementation of the `Explorer.Celo.ContractEvents.EventTransformer` protocol to allow transformation between
      Explorer.Chain.Log, Explorer.Chain.CeloContractEvent and the generated struct
    * Ecto query functions for each parameter of type `:address` in the format `query_by_<property name>(query, address)`
      * e.g. for an event with address properties called "owner" and "supplier", the functions `query_by_owner` and
      `query_by_supplier` will be generated at compile time.
  """

  # credo complains about imports + aliases being scattered throughout the module, which shouldn't apply for macros
  # credo:disable-for-this-file
  defmacro __using__(opts) do
    name = Keyword.get(opts, :name)
    topic = Keyword.get(opts, :topic)

    quote do
      import Explorer.Celo.ContractEvents.Base
      @before_compile unquote(__MODULE__)

      Module.register_attribute(__MODULE__, :params, accumulate: true)

      alias Explorer.Chain.CeloContractEvent
      import Ecto.Query

      @name unquote(name)
      @topic unquote(topic)

      def name, do: @name
      def topic, do: @topic

      def query do
        from(c in CeloContractEvent, where: c.topic == ^@topic)
      end
    end
  end

  defmacro event_param(name, type, indexed) do
    quote do
      @params %{name: unquote(name), type: unquote(type), indexed: unquote(indexed)}
      :ok
    end
  end

  defmacro __before_compile__(env) do
    # properties specific to event instance
    # reverse as elixir module attributes are pushed to top of list and we rely on defined event property order
    unique_event_properties = env.module |> Module.get_attribute(:params) |> Enum.reverse()

    # properties common to all events
    # prefixing with underscores to prevent collisions with generated event properties
    common_event_properties = [
      :__transaction_hash,
      :__block_number,
      :__contract_address_hash,
      :__log_index,
      __name: Module.get_attribute(env.module, :name),
      __topic: Module.get_attribute(env.module, :topic)
    ]

    full_struct_properties =
      unique_event_properties
      |> Enum.map(& &1.name)
      |> Enum.concat(common_event_properties)

    # referencing module within derived methods of protocol implementation
    event_module = env.module

    unindexed_properties =
      unique_event_properties
      |> Enum.filter(&(&1.indexed == :unindexed))

    unindexed_types =
      unindexed_properties
      |> Enum.map(& &1.type)

    indexed_types_with_topics =
      unique_event_properties
      |> Enum.filter(&(&1.indexed == :indexed))
      |> Enum.zip([:second_topic, :third_topic, :fourth_topic])

    # Define a struct based on declared event properties
    struct_def =
      quote do
        defstruct unquote(full_struct_properties)
      end

    # Implement EventTransformer protocol to convert between CeloContractEvent, Chain.Log, and this generated type
    protocol_impl =
      quote do
        defimpl Explorer.Celo.ContractEvents.EventTransformer do
          import Explorer.Celo.ContractEvents.Common
          alias Explorer.Chain.{CeloContractEvent, Log}

          # coerce an Explorer.Chain.Log instance into a Map and treat the same as EthereumJSONRPC log params
          def from_log(_, %Log{} = log) do
            params = log |> Map.from_struct()
            from_params(nil, params)
          end

          # decode blockchain log data into event relevant properties
          def from_params(_, params) do
            # creating a map of unindexed (appear in event data) event properties %{name => value}
            unindexed_event_properties =
              decode_event_data(params.data, unquote(Macro.escape(unindexed_types)))
              |> Enum.zip(unquote(Macro.escape(unindexed_properties)))
              |> Enum.map(fn {data, %{name: name}} -> {name, data} end)
              |> Enum.into(%{})

            # creating a map of indexed (appear in event topics) event properties %{name => value}
            indexed_event_properties =
              unquote(Macro.escape(indexed_types_with_topics))
              |> Enum.map(fn {%{name: name, type: type}, topic} ->
                {name, decode_event_topic(params[topic], type)}
              end)
              |> Enum.into(%{})

            # mapping common event properties
            common_event_properties = %{
              __transaction_hash: params.transaction_hash,
              __block_number: params.block_number,
              __topic: params.first_topic,
              __contract_address_hash: params.address_hash,
              __log_index: params.index
            }

            # instantiate a struct from properties
            common_event_properties
            |> Map.merge(indexed_event_properties)
            |> Map.merge(unindexed_event_properties)
            |> then(&struct(unquote(event_module), &1))
          end

          # create a concrete event instance from a CeloContractEvent
          def from_celo_contract_event(_, %CeloContractEvent{params: params} = contract) do
            event_params =
              params
              |> normalise_map()
              |> Map.take(unquote(Macro.escape(full_struct_properties)))
              |> Enum.map(fn
                {k, v = "\\x" <> _rest} ->
                  {k, cast_address(v)}

                {k, v} ->
                  {k, v}
              end)
              |> Enum.into(%{})

            %{
              __transaction_hash: contract.transaction_hash,
              __block_number: contract.block_number,
              __topic: contract.topic,
              __contract_address_hash: contract.contract_address_hash,
              __log_index: contract.log_index,
              __name: contract.name
            }
            |> Map.merge(event_params)
            |> then(&struct(unquote(event_module), &1))
          end

          # params to be provided to CeloContractEvent changeset
          def to_celo_contract_event_params(event) do
            event_params =
              unquote(Macro.escape(unique_event_properties))
              |> Enum.map(fn
                %{name: name, type: :address} -> {name, Map.get(event, name) |> format_address_for_postgres_json()}
                %{name: name} -> {name, Map.get(event, name)}
              end)
              |> Enum.into(%{})

            event
            |> extract_common_event_params()
            |> Map.merge(%{params: event_params})
          end

          def to_event_stream_format(event) do
            event_params =
              unquote(Macro.escape(unique_event_properties))
              |> Enum.map(fn
                %{name: name, type: :address} -> {name, Map.get(event, name) |> format_address_for_streaming()}
                %{name: name} -> {name, Map.get(event, name)}
              end)
              |> Enum.into(%{})

            event
            |> extract_common_event_params()
            |> Map.merge(%{params: event_params})
            |> Jason.encode!()
          end
        end
      end

    # define queries for address types
    dynamic_queries =
      unique_event_properties
      |> Enum.filter(&(&1.type == :address))
      |> Enum.map(fn %{name: name} ->
        quote do
          alias Explorer.Celo.ContractEvents.Common
          import Ecto.Query

          # sobelow_skip ["DOS.BinToAtom"]
          def unquote(:"query_by_#{name}")(query, address) do
            address = Common.format_address_for_postgres_json(address)

            from(c in query,
              where: fragment("? ->> ? = ?", c.params, unquote(Atom.to_string(name)), ^address)
            )
          end
        end
      end)

    # return multiple generated AST nodes - merge all the above `quote` statements into the module definition
    [struct_def, protocol_impl, dynamic_queries] |> List.flatten()
  end
end
