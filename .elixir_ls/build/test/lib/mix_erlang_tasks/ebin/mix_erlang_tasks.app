{application,mix_erlang_tasks,
             [{applications,[kernel,stdlib,elixir]},
              {description,"This project provides a few Mix tasks that make it more convenient to use Mix as a build tool and package manager when developing applications in Erlang."},
              {modules,['Elixir.Mix.Tasks.Ct','Elixir.Mix.Tasks.Edoc',
                        'Elixir.Mix.Tasks.Eunit',
                        'Elixir.MixErlangTasks.Util']},
              {registered,[]},
              {vsn,"0.1.0"}]}.
