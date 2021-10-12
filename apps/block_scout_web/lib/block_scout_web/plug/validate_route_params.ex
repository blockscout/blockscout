defmodule BlockScoutWeb.Plug.ValidateRouteParameters do
  @moduledoc """
  Validates route parameters

  To trigger validation, a map of keys to validation functions / atoms must be set under the `:validate` key in the
  the private field of the Plug.Conn object. This plug is designed to fail safe, that is - unless a parameter has
  been found to be explicitly invalid it will be treated as valid.

  Validation functions can be any function that returns a boolean variable or :is_address which invokes
  Explorer.Chain.Hash.Address.validate/1.
  """

  import BlockScoutWeb.Controller, only: [validation_failed: 1]

  alias Explorer.Chain.Hash.Address

  def init(opts), do: opts

  def call(%{params: params, private: %{validate: validation}} = conn, _) do
    validate(conn, params, validation)
  end

  def call(conn, _), do: conn

  def validate(conn, params, validation) when is_map(validation) do
    invalid =
      validation
      |> Enum.map(fn {param, validate_func} ->
        perform_validation(params[param], validate_func)
      end)
      |> Enum.any?(fn valid -> valid == false end)

    if invalid do
      conn
      |> validation_failed()
    else
      conn
    end
  end

  def validate(conn, %{}, _validation), do: conn
  def validate(conn, _, _), do: conn

  def perform_validation(nil, _validator), do: true
  def perform_validation(p, validator) when is_function(validator), do: validator.(p)

  def perform_validation(p, validator) when is_atom(validator) do
    case validator do
      :is_address -> perform_validation(p, &is_address/1)
    end
  end

  defp is_address("0x" <> _hash = param) do
    case Address.validate(param) do
      {:ok, _} -> true
      _ -> false
    end
  end

  # is not a hex encoded string
  defp is_address(_hash), do: false
end
