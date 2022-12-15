defmodule Indexer.Fetcher do
  @moduledoc """
  General fetcher infrastructure.
  """

  alias Macro.Env

  defmacro __using__(opts \\ []) do
    quote do
      require Indexer.Fetcher

      Indexer.Fetcher.defsupervisor(unquote(opts))
    end
  end

  # credo:disable-for-next-line Credo.Check.Refactor.CyclomaticComplexity
  defmacro defsupervisor(opts \\ []) do
    quote location: :keep do
      opts = unquote(opts)

      strategy = Keyword.get(opts, :strategy, :one_for_one)
      fetcher = __MODULE__
      supervisor = Keyword.get(opts, :supervisor, Module.concat(fetcher, Supervisor))
      task_supervisor = Keyword.get(opts, :task_supervisor, Module.concat(fetcher, TaskSupervisor))
      restart = Keyword.get(opts, :restart, :transient)

      Module.create(
        supervisor,
        quote bind_quoted: [strategy: strategy, fetcher: fetcher, task_supervisor: task_supervisor, restart: restart] do
          use Supervisor

          def child_spec([]), do: child_spec([[], []])
          def child_spec([init_arguments]), do: child_spec([init_arguments, []])

          def child_spec([_init_arguments, _gen_server_options] = start_link_arguments) do
            default = %{
              id: __MODULE__,
              start: {__MODULE__, :start_link, start_link_arguments},
              restart: unquote(restart),
              type: :supervisor
            }

            Supervisor.child_spec(default, [])
          end

          def start_link(arguments, gen_server_options \\ []) do
            if disabled?() do
              :ignore
            else
              Supervisor.start_link(__MODULE__, arguments, Keyword.put_new(gen_server_options, :name, __MODULE__))
            end
          end

          def disabled? do
            Application.get_env(:indexer, __MODULE__, [])[:disabled?] == true
          end

          @impl Supervisor
          def init(fetcher_arguments) do
            children = [
              {Task.Supervisor, name: unquote(task_supervisor)},
              {unquote(fetcher), [put_supervisor_when_is_list(fetcher_arguments), [name: unquote(fetcher)]]}
            ]

            Supervisor.init(children, strategy: unquote(strategy))
          end

          defp put_supervisor_when_is_list(arguments) when is_list(arguments) do
            Keyword.put(arguments, :supervisor, self())
          end

          defp put_supervisor_when_is_list(arguments), do: arguments
        end,
        Env.location(__ENV__)
      )
    end
  end
end
