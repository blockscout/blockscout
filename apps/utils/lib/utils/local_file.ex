# SPDX-License-Identifier: LicenseRef-Blockscout
defmodule Utils.LocalFile do
  @moduledoc """
  Guarded reading of local files whose paths come from configuration.

  Env variables that accept a local file path could otherwise be pointed at
  any file readable by the application. This module narrows that surface by
  only reading regular files with an expected extension. Validation of the
  file content is left to the caller, since it depends on the expected format.
  """

  @type error_reason ::
          {:invalid_file_extension, String.t(), [String.t()]}
          | :not_a_regular_file
          | File.posix()

  @doc """
  Reads a local file if its extension is one of `allowed_extensions`.

  The extension is compared case-insensitively and must include the leading
  dot (e.g. `".json"`). Directories, devices, sockets and other non-regular
  files are rejected.

  ## Parameters
  - `path`: Path to the local file.
  - `allowed_extensions`: Extensions the file is allowed to have.

  ## Returns
  - `{:ok, content}` if the file passed the checks and was read.
  - `{:error, {:invalid_file_extension, extension, allowed_extensions}}` if
    the file has an unexpected extension.
  - `{:error, :not_a_regular_file}` if the path is not a regular file.
  - `{:error, posix}` if the file cannot be read.
  """
  @spec read(String.t(), [String.t()]) :: {:ok, binary()} | {:error, error_reason()}
  # sobelow_skip ["Traversal.FileModule"]
  def read(path, allowed_extensions) when is_binary(path) and is_list(allowed_extensions) do
    with :ok <- validate_extension(path, allowed_extensions),
         :ok <- validate_regular_file(path) do
      File.read(path)
    end
  end

  @doc """
  Checks that the extension of `path` is one of `allowed_extensions`.

  ## Returns
  - `:ok` if the extension is allowed.
  - `{:error, {:invalid_file_extension, extension, allowed_extensions}}` otherwise.
  """
  @spec validate_extension(String.t(), [String.t()]) ::
          :ok | {:error, {:invalid_file_extension, String.t(), [String.t()]}}
  def validate_extension(path, allowed_extensions) when is_binary(path) and is_list(allowed_extensions) do
    extension = path |> Path.extname() |> String.downcase()

    if extension in allowed_extensions do
      :ok
    else
      {:error, {:invalid_file_extension, extension, allowed_extensions}}
    end
  end

  @spec validate_regular_file(String.t()) :: :ok | {:error, :not_a_regular_file | File.posix()}
  # sobelow_skip ["Traversal.FileModule"]
  defp validate_regular_file(path) do
    case File.stat(path) do
      {:ok, %File.Stat{type: :regular}} -> :ok
      {:ok, _} -> {:error, :not_a_regular_file}
      {:error, reason} -> {:error, reason}
    end
  end
end
