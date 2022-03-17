defmodule Mix.Tasks.EventMap do
  @moduledoc "Build a map of celo contract events to topics"

  use Mix.Task

  alias Explorer.Celo.ContractEvents.EventTransformer

  @template """
  # This file is auto generated, changes will be lost upon regeneration

  defmodule Explorer.Celo.ContractEvents.EventMap do
    @moduledoc "Map event names and event topics to concrete contract event structs"

    alias Explorer.Celo.ContractEvents.EventTransformer
    alias Explorer.Repo

    @doc "Convert ethrpc log parameters to CeloContractEvent insertion parameters"
    def rpc_to_event_params(logs) when is_list(logs) do
      logs
      |> Enum.map(fn params = %{first_topic: event_topic} ->
        case event_for_topic(event_topic) do
          nil ->
            nil

          event ->
            event
            |> struct!()
            |> EventTransformer.from_params(params)
            |> EventTransformer.to_celo_contract_event_params()
        end
      end)
      |> Enum.reject(&is_nil/1)
    end

    @doc "Convert CeloContractEvent instance to their concrete types"
    def celo_contract_event_to_concrete_event(events) when is_list(events) do
      events
      |> Enum.map(&celo_contract_event_to_concrete_event/1)
      |> Enum.reject(&is_nil/1)
    end

    def celo_contract_event_to_concrete_event(%{topic: topic} = params) do
      case event_for_topic(topic) do
        nil ->
          nil

        event ->
          event
          |> struct!()
          |> EventTransformer.from_celo_contract_event(params)
      end
    end

    @doc "Run ecto query and convert all CeloContractEvents into their concrete types"
    def query_all(query) do
      query
      |> Repo.all()
      |> celo_contract_event_to_concrete_event()
    end

    @doc "Convert concrete event to CeloContractEvent insertion parameters"
    def event_to_contract_event_params(events) when is_list(events) do
      events |> Enum.map(&event_to_contract_event_params/1)
    end

    def event_to_contract_event_params(event) do
      event |> EventTransformer.to_celo_contract_event_params()
    end

    @topic_to_event %{
    <%= for module <- @modules do %>  "<%= module.topic %>" =>
      <%= module %>,
    <% end %>}

    def event_for_topic(topic), do: Map.get(@topic_to_event, topic)
    def map, do: @topic_to_event

  end

  """

  @path "lib/explorer/celo/events/contract_events/event_map.ex"

  @shortdoc "Creates a module mapping topics to event names and vice versa"
  def run(args) do
    {options, _, _} = OptionParser.parse(args, strict: [verbose: :boolean])

    modules = get_events()
    event_map = EEx.eval_string(@template, assigns: [modules: modules])

    if Keyword.get(options, :verbose) do
      IO.puts(event_map)
    end

    _ = File.rm(@path)
    File.write(@path, event_map)
  end

  @dialyzer {:nowarn_function, get_events: 0}
  defp get_events do
    :impls
    |> EventTransformer.__protocol__()
    |> then(fn
      {:consolidated, modules} ->
        modules

      _ ->
        Protocol.extract_impls(
          Explorer.Celo.ContractEvents.EventTransformer,
          [:code.lib_dir(:explorer, :ebin)]
        )
    end)
  end
end
