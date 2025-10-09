defmodule Utils.Credo.Checks.CompileEnvUsageTest do
  use Credo.Test.Case

  alias Utils.Credo.Checks.CompileEnvUsage

  test "finds violations" do
    """
    defmodule CredoSampleModule do
      @test Application.compile_env(:blockscout, :test)
    end
    """
    |> to_source_file()
    |> run_check(CompileEnvUsage)
    |> assert_issue()
  end

  test "ignores compile_time_env_helper.ex" do
    """
    defmodule CredoSampleModule do
      @test Application.compile_env(:blockscout, :test)
    end
    """
    |> to_source_file("utils/compile_time_env_helper.ex")
    |> run_check(CompileEnvUsage)
    |> refute_issues()
  end

  test "no false positives" do
    """
    defmodule CredoSampleModule do
      use Utils.CompileTimeEnvHelper, test: [:blockscout, :test]
    end
    """
    |> to_source_file()
    |> run_check(CompileEnvUsage)
    |> refute_issues()
  end
end
