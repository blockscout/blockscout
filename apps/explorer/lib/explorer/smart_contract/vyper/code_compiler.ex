defmodule Explorer.SmartContract.Vyper.CodeCompiler do
  @moduledoc """
  Module responsible to compile the Vyper code of a given Smart Contract.
  """

  alias Explorer.SmartContract.VyperDownloader

  @spec run(Keyword.t()) :: {:ok, map} | {:error, :compilation | :name}
  def run(params) do
    compiler_version = Keyword.fetch!(params, :compiler_version)
    code = Keyword.fetch!(params, :code)

    path = VyperDownloader.ensure_exists(compiler_version)

    source_file_path = create_source_file(code)

    if path do
      {response, _status} =
        System.cmd(
          path,
          [
            "-f",
            "abi,bytecode",
            source_file_path
          ]
        )

      response_data = String.split(response, "\n")
      abi_row = response_data |> Enum.at(0)
      bytecode = response_data |> Enum.at(1)

      case Jason.decode(abi_row) do
        {:ok, abi} ->
          {:ok, %{"abi" => abi, "bytecode" => bytecode}}

        {:error, %Jason.DecodeError{}} ->
          {:error, :compilation}
      end
    else
      {:error, :compilation}
    end
  end

  def get_contract_info(contracts, _) when contracts == %{}, do: {:error, :compilation}

  def get_contract_info(contracts, name) do
    new_versions_name = ":" <> name

    case contracts do
      %{^new_versions_name => response} ->
        response

      %{^name => response} ->
        response

      _ ->
        {:error, :name}
    end
  end

  def parse_error({:error, %{"error" => error}}), do: {:error, [error]}
  def parse_error({:error, %{"errors" => errors}}), do: {:error, errors}
  def parse_error({:error, _} = error), do: error

  defp create_source_file(source) do
    {:ok, path} = Briefly.create()

    File.write!(path, source)

    path
  end
end
