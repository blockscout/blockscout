defmodule Utils.Credo.Checks.ModuleNamesPreferredCasing do
  @moduledoc """
  Ensures module names use preferred casing for acronyms and proper names.

  This check examines `defmodule` declarations and inspects each segment (split
  by `.`) and CamelCase tokens within segments to ensure:
  - Preferred casing is used for known proper names (e.g., GraphQL)
  - Uppercase acronyms are written in all caps (e.g., API, DB, RPC, HTTP)
  - Inline acronyms within a token are capitalized when they start a token
    (e.g., ApiRouter → APIRouter, HttpClient → HTTPClient)

  You can extend the allowlists inside this file when the domain introduces new
  terms or acronyms.
  """

  @explanation [check: @moduledoc, params: []]

  use Credo.Check, base_priority: :normal, category: :readability

  alias Credo.{Code, IssueMeta, SourceFile}

  # Preferred terms list: include both acronyms (all-caps) and proper names.
  # Extend this list to introduce new domain terms.
  @preferred_terms_list [
    # Proper names / brands
    "GraphQL",
    "ZkSync",
    # Acronyms (all caps)
    "API",
    "RPC",
    "HTTP",
    "HTTPS",
    "JSON",
    "CSV",
    "DB",
    "URL",
    "URI",
    "UUID",
    "IPFS",
    "TCP",
    "UDP",
    "DNS",
    "SSL",
    "TLS",
    "WS",
    "WSS",
    "NFT",
    "EVM",
    "L1",
    "L2",
    "L3",
    "MEV"
  ]

  @impl true
  def run(%SourceFile{} = source_file, params \\ []) do
    issue_meta = IssueMeta.for(source_file, params)

    preferred =
      @preferred_terms_list
      |> Enum.map(&{String.downcase(&1), &1})
      |> Enum.sort_by(fn {key, _expected} -> -String.length(key) end)

    Code.prewalk(source_file, &traverse(&1, &2, issue_meta, preferred))
  end

  defp traverse({:defmodule, _meta, [module_ast, _]} = ast, issues, issue_meta, preferred) do
    parts = extract_alias_parts(module_ast)
    full = Enum.map_join(parts, ".", &Atom.to_string/1)

    new_issues =
      parts
      |> Enum.flat_map(fn part ->
        human = Atom.to_string(part)
        lower = String.downcase(human)

        mismatches = find_mismatches_for_part(human, lower, preferred)

        Enum.map(mismatches, fn {expected, actual} ->
          format_issue(issue_meta, expected, actual, full)
        end)
      end)

    {ast, new_issues ++ issues}
  end

  defp traverse(ast, issues, _issue_meta, _preferred), do: {ast, issues}

  defp extract_alias_parts({:__aliases__, _meta, parts}) when is_list(parts), do: parts
  defp extract_alias_parts(name) when is_atom(name), do: [name]

  defp extract_alias_parts(other) do
    # Fallback for unexpected AST shapes
    other
    |> Macro.to_string()
    |> String.split(".")
    |> Enum.map(&String.to_atom/1)
  rescue
    _ -> []
  end

  # Returns list of {expected, actual} for each mismatched term occurrence within a module part.
  defp find_mismatches_for_part(human, lower, preferred_pairs) do
    candidates =
      Enum.flat_map(preferred_pairs, fn {key, expected} ->
        for {pos, len} <- :binary.matches(lower, key) do
          %{pos: pos, len: len, stop: pos + len, expected: expected}
        end
      end)

    # Prefer longer matches first to avoid partial overlaps (e.g., HTTPS vs HTTP)
    sorted = Enum.sort_by(candidates, fn %{len: len} -> -len end)

    {_claimed, acc} =
      Enum.reduce(sorted, {[], []}, fn %{
                                         pos: pos,
                                         stop: stop,
                                         len: len,
                                         expected: expected
                                       },
                                       {claimed, acc} ->
        actual = binary_part(human, pos, len)

        if boundary_ok?(human, pos) and not overlaps_any?({pos, stop}, claimed) and actual != expected do
          {[{pos, stop} | claimed], [{expected, actual} | acc]}
        else
          {claimed, acc}
        end
      end)

    Enum.reverse(acc)
  end

  # A match is considered on a CamelCase boundary if it starts the string or
  # begins at an uppercase letter (typical CamelCase token start).
  defp boundary_ok?(_string, 0), do: true

  defp boundary_ok?(string, idx) when is_integer(idx) and idx > 0 do
    case String.at(string, idx) do
      nil -> false
      <<_::utf8>> = ch -> ch =~ ~r/^[A-Z]$/
    end
  end

  defp overlaps_any?({_s1, _e1} = a, ranges), do: Enum.any?(ranges, &overlap?(a, &1))

  defp overlap?({s1, e1}, {s2, e2}), do: not (e1 <= s2 or e2 <= s1)

  defp format_issue(issue_meta, expected, actual, full_module) do
    format_issue(
      issue_meta,
      message:
        "Module names should use preferred casing (acronyms/proper names): expected '#{expected}', found '#{actual}' in '#{full_module}'. See CONTRIBUTING.md > Basic Naming Convention.",
      trigger: actual
    )
  end
end
