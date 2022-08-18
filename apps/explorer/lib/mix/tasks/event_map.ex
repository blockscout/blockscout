defmodule Mix.Tasks.EventMap do
  @moduledoc "Build a map of celo contract events to topics"

  use Mix.Task

  alias Explorer.Celo.ContractEvents.EventTransformer
  require Logger

  @path "lib/explorer/celo/events/celo_contract_events/event_map.ex"
  @template "lib/mix/tasks/event_map_template.eex"
  @shortdoc "Creates a module mapping topics to event names and vice versa"
  def run(args) do
    {options, _, _} = OptionParser.parse(args, strict: [verbose: :boolean])

    modules = get_events()

    Logger.info("Found #{length(modules)} Celo contract events defined in the Explorer application")
    event_map = EEx.eval_file(@template, assigns: [modules: modules])

    if Keyword.get(options, :verbose) do
      IO.puts(event_map)
    end

    _ = File.rm(@path)
    File.write(@path, event_map)

    Logger.info("Wrote event map to #{@path}")
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
