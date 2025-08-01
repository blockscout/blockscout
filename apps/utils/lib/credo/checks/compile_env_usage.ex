defmodule Utils.Credo.Checks.CompileEnvUsage do
  @moduledoc """
  Disallows usage of Application.compile_env throughout the codebase,
  except in Utils.CompileTimeEnvHelper module.

  Application.compile_env should generally be avoided as it makes the code
  harder to test and configure dynamically.
  """

  @explanation [
    check: @moduledoc,
    params: []
  ]

  use Credo.Check, base_priority: :high, category: :warning

  alias Credo.Code

  @doc false
  @impl true
  def run(%SourceFile{} = source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    # Skip check for Utils.CompileTimeEnvHelper module
    if String.ends_with?(source_file.filename, "utils/compile_time_env_helper.ex") do
      []
    else
      Code.prewalk(source_file, &traverse(&1, &2, issue_meta))
    end
  end

  defp traverse({:., _, [{:__aliases__, _, [:Application]}, :compile_env]} = ast, issues, issue_meta) do
    {ast, [issue_for(issue_meta, Macro.to_string(ast)) | issues]}
  end

  defp traverse({:., _, [{:__aliases__, _, [:Application]}, :compile_env!]} = ast, issues, issue_meta) do
    {ast, [issue_for(issue_meta, Macro.to_string(ast)) | issues]}
  end

  defp traverse(ast, issues, _issue_meta) do
    {ast, issues}
  end

  defp issue_for(issue_meta, trigger) do
    format_issue(
      issue_meta,
      message: """
      Avoid using Application.compile_env, use runtime configuration instead. If you need compile-time config, use Utils.CompileTimeEnvHelper.
      More details: https://github.com/blockscout/blockscout/tree/master/CONTRIBUTING.md#compile-time-environment-variables
      """,
      trigger: trigger
    )
  end
end
