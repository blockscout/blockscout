# This file contains the configuration for Credo and you are probably reading
# this after creating it with `mix credo.gen.config`.
#
# If you find anything wrong or unclear in this file, please report an
# issue on GitHub: https://github.com/rrrene/credo/issues
#
%{
  #
  # You can have as many configs as you like in the `configs:` field.
  configs: [
    %{
      #
      # Run any exec using `mix credo -C <name>`. If no exec name is given
      # "default" is used.
      #
      name: "default",
      #
      # These are the files included in the analysis:
      files: %{
        #
        # You can give explicit globs or simply directories.
        # In the latter case `**/*.{ex,exs}` will be used.
        #
        included: ["lib/", "src/", "web/", "apps/*/lib/**/*.{ex,exs}"],
        excluded: [
          ~r"/_build/",
          ~r"/deps/",
          ~r"/node_modules/",
          ~r"/apps/block_scout_web/lib/block_scout_web.ex"
        ]
      },
      #
      # If you create your own checks, you must specify the source files for
      # them here, so they can be loaded by Credo before running the analysis.
      #
      requires: ["apps/utils/lib/credo/**/*.ex"],
      #
      # If you want to enforce a style guide and need a more traditional linting
      # experience, you can change `strict` to `true` below:
      #
      strict: true,
      #
      # If you want to use uncolored output by default, you can change `color`
      # to `false` below:
      #
      color: true,
      #
      # You can customize the parameters of any check by adding a second element
      # to the tuple.
      #
      # To disable a check put `false` as second element:
      #
      #     {Credo.Check.Design.DuplicatedCode, false}
      #
      checks: [
        # outdated by formatter in Elixir 1.6.  See https://github.com/rrrene/credo/issues/505
        {Credo.Check.Consistency.LineEndings, false},
        {Credo.Check.Consistency.SpaceAroundOperators, false},
        {Credo.Check.Consistency.SpaceInParentheses, false},
        {Credo.Check.Consistency.TabsOrSpaces, false},
        {Credo.Check.Readability.LargeNumbers, false},
        {Credo.Check.Readability.MaxLineLength, false},
        {Credo.Check.Readability.ParenthesesInCondition, false},
        {Credo.Check.Readability.RedundantBlankLines, false},
        {Credo.Check.Readability.Semicolons, false},
        {Credo.Check.Readability.SpaceAfterCommas, false},
        {Credo.Check.Readability.TrailingBlankLine, false},
        {Credo.Check.Readability.TrailingWhiteSpace, false},

        # outdated by lazy Logger in Elixir 1.7.  See https://elixir-lang.org/blog/2018/07/25/elixir-v1-7-0-released/
        {Credo.Check.Warning.LazyLogging, false},

        # not handled by formatter
        {Credo.Check.Consistency.ExceptionNames},
        {Credo.Check.Consistency.ParameterPatternMatching},

        # You can customize the priority of any check
        # Priority values are: `low, normal, high, higher`
        #
        {Credo.Check.Design.AliasUsage,
         excluded_namespaces: ~w(Block Blocks Import Runner Socket SpandexDatadog Task),
         excluded_lastnames:
           ~w(Address DateTime Exporter Fetcher Full Instrumenter Logger Monitor Name Number Repo Spec Time Unit),
         priority: :low},

        # For some checks, you can also set other parameters
        #
        # If you don't want the `setup` and `test` macro calls in ExUnit tests
        # or the `schema` macro in Ecto schemas to trigger DuplicatedCode, just
        # set the `excluded_macros` parameter to `[:schema, :setup, :test]`.
        #
        {Credo.Check.Design.DuplicatedCode, excluded_macros: [], mass_threshold: 80},

        # You can also customize the exit_status of each check.
        # If you don't want TODO comments to cause `mix credo` to fail, just
        # set this value to 0 (zero).
        #
        {Credo.Check.Design.TagTODO, exit_status: 0},
        {Credo.Check.Design.TagFIXME},
        {Credo.Check.Readability.FunctionNames},
        {Credo.Check.Readability.ModuleAttributeNames},
        {Credo.Check.Readability.ModuleDoc},
        {Credo.Check.Readability.ModuleNames},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs},
        {Credo.Check.Readability.PredicateFunctionNames},
        {Credo.Check.Readability.PreferImplicitTry},
        {Credo.Check.Readability.StringSigils},
        {Credo.Check.Readability.VariableNames},
        {Credo.Check.Refactor.DoubleBooleanNegation},
        {Credo.Check.Refactor.CondStatements},
        {Credo.Check.Refactor.CyclomaticComplexity},
        {Credo.Check.Refactor.FunctionArity},
        {Credo.Check.Refactor.LongQuoteBlocks},
        {Credo.Check.Refactor.MatchInCondition},
        {Credo.Check.Refactor.NegatedConditionsInUnless},
        {Credo.Check.Refactor.NegatedConditionsWithElse},
        {Credo.Check.Refactor.Nesting},
        {Credo.Check.Refactor.PipeChainStart},
        {Credo.Check.Refactor.UnlessWithElse},
        {Credo.Check.Warning.BoolOperationOnSameValues},
        {Credo.Check.Warning.ExpensiveEmptyEnumCheck},
        {Credo.Check.Warning.IExPry},
        {Credo.Check.Warning.IoInspect},
        {Credo.Check.Warning.OperationOnSameValues},
        {Credo.Check.Warning.OperationWithConstantResult},
        {Credo.Check.Warning.UnusedEnumOperation},
        {Credo.Check.Warning.UnusedFileOperation},
        {Credo.Check.Warning.UnusedKeywordOperation},
        {Credo.Check.Warning.UnusedListOperation},
        {Credo.Check.Warning.UnusedPathOperation},
        {Credo.Check.Warning.UnusedRegexOperation},
        {Credo.Check.Warning.UnusedStringOperation},
        {Credo.Check.Warning.UnusedTupleOperation},
        {Credo.Check.Warning.RaiseInsideRescue},

        # Controversial and experimental checks (opt-in, just remove `, false`)
        #
        # TODO reenable before merging optimized-indexer branch
        {Credo.Check.Refactor.ABCSize, false},
        {Credo.Check.Refactor.AppendSingleItem},
        {Credo.Check.Refactor.VariableRebinding},
        {Credo.Check.Warning.MapGetUnsafePass},
        {Credo.Check.Consistency.MultiAliasImportRequireUse},

        # Custom checks can be created using `mix credo.gen.check`.
        {Utils.Credo.Checks.CompileEnvUsage}
        #
      ]
    }
  ]
}
