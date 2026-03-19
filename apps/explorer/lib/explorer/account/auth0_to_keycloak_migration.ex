defmodule Explorer.Account.Auth0ToKeycloakMigration do
  @moduledoc """
  Migrates users from Auth0 to Keycloak in bulk using batch APIs.

  Supports merging multiple Auth0 tenants (different Blockscout instances) into
  a single Keycloak realm. When a user with the same email already exists in
  Keycloak (from a previous tenant migration), the new address is appended to
  the existing user's multivalued `address` attribute. Each Blockscout identity
  gets the Keycloak ID of the user matching their email.

  ## Phases
  1. Exports all Auth0 users via async job (~5 API calls instead of N)
  2. Matches DB identities with Auth0 export data (in-memory)
  3. Batch-imports users into Keycloak via partial import (~N/500 API calls)
  4. Updates identity UIDs from Auth0 ID to Keycloak UUID
  5. Deletes non-migrated identities (no user data, cascades via DB foreign keys)

  ## Usage

  ### Development (Mix)

      mix auth0_to_keycloak_migrate --dry-run
      mix auth0_to_keycloak_migrate --batch-size 200

  ### Production (Release)

  Use `rpc` to execute on the running node — this is required so that
  `Application.put_env` changes (disable account, switch to Keycloak)
  take effect on the live system. Do NOT use `eval`, as it spawns a
  separate BEAM process whose config changes are discarded on exit.

      bin/blockscout rpc "Explorer.Account.Auth0ToKeycloakMigration.run(dry_run: true)"
      bin/blockscout rpc "Explorer.Account.Auth0ToKeycloakMigration.run(batch_size: 200)"

  ## Options
  - `:dry_run` - When true, logs what would happen without making changes (default: false)
  - `:batch_size` - Number of users per Keycloak partial import batch (default: 500)

  ## Memory

  The Auth0 export is loaded into memory. For ~800k users expect ~1-2GB RAM usage.
  """
  use Utils.RuntimeEnvHelper,
    keycloak_domain: [:explorer, [Explorer.ThirdPartyIntegrations.Keycloak, :domain]],
    keycloak_realm: [:explorer, [Explorer.ThirdPartyIntegrations.Keycloak, :realm]],
    keycloak_client_id: [:explorer, [Explorer.ThirdPartyIntegrations.Keycloak, :client_id]],
    keycloak_client_secret: [:explorer, [Explorer.ThirdPartyIntegrations.Keycloak, :client_secret]],
    chain_id: [:block_scout_web, :chain_id]

  import Ecto.Query

  alias Explorer.{Account, HttpClient, Repo}
  alias Explorer.Account.{Api.Key, CustomABI, Identity, TagAddress, TagTransaction, Watchlist, WatchlistAddress}
  alias Explorer.ThirdPartyIntegrations.{Auth0, Keycloak}
  alias Explorer.ThirdPartyIntegrations.Auth0.Internal, as: Auth0Internal
  alias OAuth2.Client
  alias Ueberauth.Strategy.Auth0.OAuth

  require Logger

  @json_headers [{"content-type", "application/json"}]
  @auth0_json_headers [{"Content-type", "application/json"}]

  # Auth0 export job
  @export_min_poll_interval_ms 3_000
  @export_max_poll_interval_ms 30_000
  @export_max_total_wait_ms 1_800_000

  # Keycloak partial import
  @default_batch_size 500
  @batch_pause_ms 1_000

  @spec run(keyword()) :: [{:ok, String.t(), String.t()} | {:error, String.t(), any()}]
  def run(opts \\ []) do
    with :ok <- check_auth0_configured(),
         :ok <- check_keycloak_configured() do
      do_run(opts)
    else
      {:error, message} ->
        Logger.error(message)
        []
    end
  end

  defp check_auth0_configured do
    if Auth0.enabled?(), do: :ok, else: {:error, "Auth0 is not configured. Cannot read source users."}
  end

  defp check_keycloak_configured do
    if Keycloak.enabled?(), do: :ok, else: {:error, "Keycloak is not configured. Cannot create target users."}
  end

  defp do_run(opts) do
    dry_run = Keyword.get(opts, :dry_run, false)
    batch_size = Keyword.get(opts, :batch_size, @default_batch_size)

    unless dry_run, do: disable_account()

    case run_phases(dry_run, batch_size) do
      {:ok, results, migrated_ids} ->
        unless dry_run, do: finalize(results, migrated_ids)
        results

      {:error, reason} ->
        Logger.error("Migration failed: #{inspect(reason)}")
        unless dry_run, do: enable_account()
        []
    end
  end

  defp run_phases(dry_run, batch_size) do
    # Phase 1: Export all Auth0 users
    Logger.info("Phase 1: Exporting Auth0 users...")

    with {:ok, auth0_users} <- export_auth0_users(),
         # Phase 2: Load identities and match with Auth0 data
         Logger.info("Phase 2: Loading identities and matching with Auth0 data..."),
         identities = load_auth0_identities(),
         {[_ | _] = items, skipped_with_data} <- build_migration_items(identities, auth0_users) do
      execute_or_dry_run(items, skipped_with_data, dry_run, batch_size)
    else
      {[], skipped_with_data} ->
        Logger.info("No identities to migrate")
        {:ok, [], MapSet.new(skipped_with_data)}

      {:error, _} = error ->
        error
    end
  end

  defp execute_or_dry_run(items, skipped_with_data, dry_run, batch_size) do
    Logger.info("Found #{Enum.count(items)} identities to migrate#{if dry_run, do: " (DRY RUN)"}")

    # Protect both migrated identities and skipped-with-data identities from deletion
    protected_ids =
      items
      |> MapSet.new(& &1.identity_id)
      |> MapSet.union(MapSet.new(skipped_with_data))

    if dry_run do
      log_dry_run(items)
      log_dry_run_deletion_count(protected_ids)
      {:ok, [], protected_ids}
    else
      # Phase 3: Batch import to Keycloak
      Logger.info("Phase 3: Importing users to Keycloak...")
      keycloak_map = batch_import_to_keycloak(items, batch_size)

      # Phase 4: Update identity UIDs
      Logger.info("Phase 4: Updating identity UIDs...")
      results = update_identities(items, keycloak_map)

      summarize(results)
      {:ok, results, protected_ids}
    end
  end

  defp export_auth0_users do
    with {:ok, job_id} <- create_export_job(),
         {:ok, location} <- poll_export_job(job_id) do
      download_and_parse_export(location)
    end
  end

  defp create_export_job do
    with token when is_binary(token) <- Auth0.get_m2m_jwt(),
         client = OAuth.client(token: token),
         {:ok, %OAuth2.Response{status_code: 200, body: %{"id" => job_id}}} <-
           Client.post(client, "/api/v2/jobs/users-exports", export_job_body(), @auth0_json_headers) do
      Logger.info("Auth0 export job created: #{job_id}")
      {:ok, job_id}
    else
      nil -> {:error, "Failed to get Auth0 M2M JWT"}
      error -> {:error, "Failed to create Auth0 export job: #{inspect(error)}"}
    end
  end

  defp export_job_body do
    %{
      format: "json",
      fields: [
        %{name: "user_id"},
        %{name: "email"},
        %{name: "email_verified"},
        %{name: "username"},
        %{name: "nickname"},
        %{name: "name"},
        %{name: "given_name"},
        %{name: "family_name"},
        %{name: "picture"},
        %{name: "user_metadata"},
        %{name: "app_metadata"},
        %{name: "identities"}
      ]
    }
  end

  defp poll_export_job(job_id, waited_ms \\ 0)

  defp poll_export_job(_job_id, waited_ms) when waited_ms >= @export_max_total_wait_ms do
    {:error, "Auth0 export job timed out after #{div(@export_max_total_wait_ms, 1000)}s"}
  end

  defp poll_export_job(job_id, waited_ms) do
    with token when is_binary(token) <- Auth0.get_m2m_jwt(),
         client = OAuth.client(token: token),
         {:ok, %OAuth2.Response{status_code: 200, body: body}} <-
           Client.get(client, "/api/v2/jobs/#{job_id}") do
      case body do
        %{"status" => "completed", "location" => location} ->
          Logger.info("Auth0 export job completed")
          {:ok, location}

        %{"status" => "failed"} ->
          {:error, "Auth0 export job failed: #{inspect(body)}"}

        %{"status" => status} = response ->
          sleep_ms = poll_interval_from_estimate(response)

          Logger.info(
            "Auth0 export status: #{status}, " <>
              "estimated time left: #{response["time_left_seconds"] || "unknown"}s, " <>
              "polling again in #{div(sleep_ms, 1000)}s (waited #{div(waited_ms, 1000)}s total)"
          )

          Process.sleep(sleep_ms)
          poll_export_job(job_id, waited_ms + sleep_ms)
      end
    else
      nil -> {:error, "Failed to get Auth0 M2M JWT"}
      error -> {:error, "Failed to poll Auth0 export job: #{inspect(error)}"}
    end
  end

  defp poll_interval_from_estimate(%{"time_left_seconds" => seconds}) when is_number(seconds) and seconds > 0 do
    (seconds * 250)
    |> round()
    |> max(@export_min_poll_interval_ms)
    |> min(@export_max_poll_interval_ms)
  end

  defp poll_interval_from_estimate(_response), do: @export_min_poll_interval_ms

  defp download_and_parse_export(location) do
    Logger.info("Downloading Auth0 export...")

    case HttpClient.get(location, []) do
      {:ok, %{status_code: 200, body: body}} ->
        text = safe_gunzip(body)

        users_map =
          text
          |> String.split("\n", trim: true)
          |> Map.new(fn line ->
            {:ok, %{"user_id" => user_id} = user} = Jason.decode(line)
            {user_id, user}
          end)

        Logger.info("Parsed #{map_size(users_map)} users from Auth0 export")
        {:ok, users_map}

      {:ok, %{status_code: status, body: resp_body}} ->
        {:error, "Failed to download Auth0 export: HTTP #{status}: #{resp_body}"}

      {:error, reason} ->
        {:error, "Failed to download Auth0 export: #{inspect(reason)}"}
    end
  end

  # Auth0 export files are gzipped. If content is already decompressed
  # (e.g. HTTP client handled Content-Encoding), pass through as-is.
  defp safe_gunzip(data) do
    :zlib.gunzip(data)
  rescue
    ErlangError -> data
  end

  defp load_auth0_identities do
    has_user_data =
      dynamic(
        [identity: i],
        exists(from(ta in TagAddress, where: ta.identity_id == parent_as(:identity).id, select: 1)) or
          exists(from(tt in TagTransaction, where: tt.identity_id == parent_as(:identity).id, select: 1)) or
          exists(from(ca in CustomABI, where: ca.identity_id == parent_as(:identity).id, select: 1)) or
          exists(from(ak in Key, where: ak.identity_id == parent_as(:identity).id, select: 1)) or
          exists(
            from(wa in WatchlistAddress,
              join: w in Watchlist,
              on: wa.watchlist_id == w.id,
              where: w.identity_id == parent_as(:identity).id,
              select: 1
            )
          ) or i.plan_id != 1
      )

    where_condition =
      dynamic(
        [identity: i],
        ^has_user_data or not is_nil(i.email)
      )

    dynamic_select = dynamic([identity: i], %{identity: i, has_user_data: ^has_user_data})

    q =
      from(i in Identity,
        as: :identity,
        where: ^where_condition,
        select: ^dynamic_select
      )

    Repo.account_repo().all(q)
  end

  defp build_migration_items(identities, auth0_users) do
    {items, skipped, skipped_with_data} =
      Enum.reduce(identities, {[], 0, []}, fn entry, {acc, skip_count, data_acc} ->
        case build_migration_item(entry, auth0_users) do
          {:ok, item} ->
            {[item | acc], skip_count, data_acc}

          {:skip_with_data, id} ->
            {acc, skip_count + 1, [id | data_acc]}

          :skip ->
            {acc, skip_count + 1, data_acc}
        end
      end)

    if skipped > 0,
      do: Logger.warning("Skipped #{skipped} identities (not found in Auth0 export, no data, or no email+address)")

    if skipped_with_data != [] do
      Logger.warning(
        "#{length(skipped_with_data)} identities with user data were NOT found in Auth0 export " <>
          "and will be preserved (not deleted): #{inspect(skipped_with_data)}"
      )
    end

    deduplicated_items = merge_duplicate_emails(items)
    log_duplicate_addresses(deduplicated_items)
    {deduplicated_items, skipped_with_data}
  end

  # Merges identities that share the same email within this instance.
  # Uses Account.merge/1 to consolidate all user data into one identity,
  # then returns a deduplicated items list with only the surviving identities.
  defp merge_duplicate_emails(items) do
    {dupes, uniques} =
      items
      |> Enum.filter(& &1.email)
      |> Enum.group_by(& &1.email)
      |> Enum.split_with(fn {_email, group} -> length(group) > 1 end)

    no_email_items = Enum.filter(items, &is_nil(&1.email))
    unique_items = Enum.flat_map(uniques, fn {_email, [item]} -> [item] end)

    merged_items =
      Enum.map(dupes, fn {email, group} ->
        ids = Enum.map(group, & &1.identity_id)
        Logger.info("Merging #{length(group)} identities with duplicate email #{email}: #{inspect(ids)}")

        # Pick primary: prefer one with address, then with user_data
        sorted = Enum.sort_by(group, fn item -> {is_nil(item.address), !item.has_user_data} end)
        [primary | _rest] = sorted

        identities =
          ids
          |> Enum.map(&Repo.account_repo().get(Identity, &1))
          |> Enum.reject(&is_nil/1)

        # Reorder identities so primary is first
        primary_identity = Enum.find(identities, &(&1.id == primary.identity_id))
        rest_identities = Enum.reject(identities, &(&1.id == primary.identity_id))

        case Account.merge([primary_identity | rest_identities]) do
          {{:ok, _}, _} ->
            Logger.info("Merged duplicate email #{email} into identity #{primary.identity_id}")
            primary

          {{:error, reason}, _} ->
            Logger.error("Failed to merge duplicate email #{email}: #{inspect(reason)}, keeping primary only")
            primary
        end
      end)

    no_email_items ++ unique_items ++ merged_items
  end

  defp log_duplicate_addresses(items) do
    items
    |> Enum.filter(& &1.address)
    |> Enum.group_by(&to_string(&1.address))
    |> Enum.filter(fn {_addr, group} -> length(group) > 1 end)
    |> Enum.each(fn {address, group} ->
      ids = Enum.map(group, & &1.identity_id)

      Logger.warning(
        "Duplicate address within same instance: #{address}, identity IDs: #{inspect(ids)}. " <>
          "Manual resolution required."
      )
    end)
  end

  defp build_migration_item(%{identity: %{id: id, uid: auth0_id}, has_user_data: has_user_data}, auth0_users) do
    with {:ok, user} <- Map.fetch(auth0_users, auth0_id),
         identity = user |> Auth0Internal.create_auth() |> Identity.new_identity(),
         true <- has_user_data || identity.address_hash != nil,
         # Every Auth0 user should have either email or address; skip anomalies.
         keycloak_username when not is_nil(keycloak_username) <-
           identity.email || (identity.address_hash && String.downcase(to_string(identity.address_hash))) do
      {:ok,
       %{
         identity_id: id,
         auth0_id: auth0_id,
         email: identity.email,
         address: identity.address_hash,
         username: keycloak_username,
         has_user_data: has_user_data
       }}
    else
      :error ->
        Logger.warning("Auth0 user not found in export for identity #{id} (#{auth0_id})")
        if has_user_data, do: {:skip_with_data, id}, else: :skip

      nil ->
        Logger.warning("Identity #{id} (#{auth0_id}) has no email and no address in Auth0, skipping")
        if has_user_data, do: {:skip_with_data, id}, else: :skip

      false ->
        Logger.debug("No user data and no address in Auth0 for identity #{id} (#{auth0_id}), skipping")
        :skip
    end
  end

  # Creates or finds Keycloak users for each migration item.
  # Across tenants, multiple identities with the same email map to one Keycloak user.
  # Returns %{identity_id => keycloak_id}.
  defp batch_import_to_keycloak(items, batch_size) do
    # Pre-check which addresses already exist in Keycloak (from previous tenant migrations).
    # These addresses will be excluded from user bodies to preserve uniqueness.
    taken_addresses = pre_check_addresses(items)
    keycloak_users = Enum.map(items, &build_keycloak_user(&1, taken_addresses))

    Logger.info("#{length(keycloak_users)} Keycloak users to import")

    num_batches = ceil(length(keycloak_users) / batch_size)

    items_by_username = Map.new(items, &{&1.username, &1})

    username_to_keycloak_id =
      keycloak_users
      |> Enum.chunk_every(batch_size)
      |> Enum.with_index(1)
      |> Enum.flat_map(fn {batch, batch_num} ->
        Logger.info("Keycloak import batch #{batch_num}/#{num_batches}")
        results = import_batch(batch)
        unless batch_num == num_batches, do: Process.sleep(@batch_pause_ms)
        results
      end)
      |> Map.new()
      |> resolve_missing_ids(items_by_username)

    # Convert username → keycloak_id into identity_id → keycloak_id
    Map.new(items, fn %{identity_id: id, username: username} ->
      {id, Map.get(username_to_keycloak_id, username)}
    end)
  end

  defp build_keycloak_user(%{username: username, email: email, address: address}, taken_addresses) do
    normalized_address = if address, do: String.downcase(to_string(address))

    # Exclude address if already claimed by another Keycloak user
    use_address =
      if normalized_address && MapSet.member?(taken_addresses, normalized_address) do
        Logger.info(
          "Address #{normalized_address} already exists in Keycloak, " <>
            "not assigning to user #{username} (#{email || "no email"})"
        )

        nil
      else
        normalized_address
      end

    body =
      %{username: username, enabled: true}
      |> then(fn body -> if email, do: Map.merge(body, %{email: email, emailVerified: true}), else: body end)
      |> then(fn body ->
        if use_address,
          do: Map.put(body, :attributes, %{address: [use_address]}),
          else: body
      end)

    {username, body}
  end

  # Checks which addresses from migration items already exist in Keycloak.
  # Returns a MapSet of lowercased addresses that are already claimed.
  defp pre_check_addresses(items) do
    addresses =
      items
      |> Enum.filter(& &1.address)
      |> Enum.map(&String.downcase(to_string(&1.address)))
      |> Enum.uniq()

    if Enum.empty?(addresses) do
      MapSet.new()
    else
      Logger.info("Pre-checking #{length(addresses)} addresses against Keycloak...")

      taken = Enum.filter(addresses, &address_exists_in_keycloak?/1)

      if taken != [] do
        Logger.info("#{length(taken)} addresses already exist in Keycloak and will be skipped")
      end

      MapSet.new(taken)
    end
  end

  defp address_exists_in_keycloak?(address) do
    match?({:ok, [_ | _]}, Keycloak.find_users_by_address(address))
  end

  defp import_batch(user_entries) do
    users = Enum.map(user_entries, fn {_username, body} -> body end)
    entries_by_username = Map.new(user_entries)

    case keycloak_partial_import(users) do
      {:ok, %{"results" => results}} ->
        Enum.flat_map(results, fn
          %{"resourceName" => username, "id" => keycloak_id, "action" => "ADDED"} ->
            [{username, keycloak_id}]

          %{"resourceName" => username, "id" => keycloak_id, "action" => "SKIPPED"} ->
            # User already exists (same username) — append our address to their attributes
            maybe_append_address(keycloak_id, entries_by_username[username])
            [{username, keycloak_id}]

          %{"resourceName" => username, "action" => "SKIPPED"} ->
            # SKIPPED without ID — will be resolved in resolve_missing_ids
            [{username, nil}]

          other ->
            Logger.warning("Unexpected partial import result: #{inspect(other)}")
            []
        end)

      {:error, reason} ->
        Logger.error("Partial import failed: #{inspect(reason)}, falling back to individual creates")
        individual_create_fallback(user_entries)
    end
  end

  defp individual_create_fallback(user_entries) do
    Enum.map(user_entries, fn {username, body} ->
      {username, create_or_reuse_keycloak_user(body)}
    end)
  end

  defp create_or_reuse_keycloak_user(body) do
    case Keycloak.create_user(body) do
      {:ok, keycloak_id} ->
        keycloak_id

      {:error, "User already exists"} ->
        case lookup_and_append_address(body) do
          {:ok, keycloak_id} -> keycloak_id
          _ -> nil
        end

      error ->
        Logger.error("Failed to create Keycloak user #{body[:username]}: #{inspect(error)}")
        nil
    end
  end

  # When a user already exists in Keycloak (e.g. from another tenant),
  # find them by email and append the new address to their attributes.
  defp lookup_and_append_address(%{email: email} = body) when is_binary(email) do
    case Keycloak.find_users_by_email(email) do
      {:ok, [%{"id" => keycloak_id} | _]} ->
        maybe_append_address(keycloak_id, body)
        {:ok, keycloak_id}

      _ ->
        Logger.warning("User already exists but could not find by email: #{email}")
        {:error, :not_found}
    end
  end

  defp lookup_and_append_address(_body), do: {:error, :no_email}

  # For users where we didn't get a Keycloak ID (SKIPPED without id, or 409),
  # fall back to individual lookup by email/address.
  defp resolve_missing_ids(username_to_id, items_by_username) do
    missing = Enum.filter(username_to_id, fn {_username, id} -> is_nil(id) end)

    if not Enum.empty?(missing) do
      Logger.info("Resolving #{length(missing)} users without Keycloak IDs...")
    end

    Enum.reduce(missing, username_to_id, fn {username, _nil}, acc ->
      item = items_by_username[username]

      case resolve_single_user(item) do
        {:ok, keycloak_id} -> Map.put(acc, username, keycloak_id)
        :error -> acc
      end
    end)
  end

  defp resolve_single_user(%{email: email, address: address, username: username}) do
    case lookup_keycloak_user(email, address) do
      {:ok, keycloak_id} ->
        append_address_to_keycloak_user(keycloak_id, address)
        {:ok, keycloak_id}

      _ ->
        Logger.error("Could not resolve Keycloak ID for #{username}")
        :error
    end
  end

  defp lookup_keycloak_user(email, address) do
    with {:ok, []} <- maybe_find_by_email(email),
         {:ok, []} <- maybe_find_by_address(address) do
      {:error, :not_found}
    else
      {:ok, [%{"id" => keycloak_id} | _]} -> {:ok, keycloak_id}
      error -> error
    end
  end

  defp maybe_find_by_email(nil), do: {:ok, []}
  defp maybe_find_by_email(email), do: Keycloak.find_users_by_email(email)

  defp maybe_find_by_address(nil), do: {:ok, []}
  defp maybe_find_by_address(address), do: Keycloak.find_users_by_address(address)

  # Extracts address from a Keycloak user body and appends it to the existing user.
  defp maybe_append_address(keycloak_id, %{attributes: %{address: [address | _]}}) do
    append_address_to_keycloak_user(keycloak_id, address)
  end

  defp maybe_append_address(_keycloak_id, _body), do: :ok

  # Appends an address to a Keycloak user's multivalued address attribute.
  # Address uniqueness is already guaranteed by pre_check_addresses — addresses
  # claimed by other users were excluded from bodies before import started.
  defp append_address_to_keycloak_user(keycloak_id, address) when is_binary(address) do
    address = String.downcase(to_string(address))

    with {:ok, user} <- Keycloak.get_user(keycloak_id) do
      current_addresses = get_in(user, ["attributes", "address"]) || []

      if address in current_addresses do
        Logger.debug("Address #{address} already on Keycloak user #{keycloak_id}")
        :ok
      else
        new_attributes = Map.put(user["attributes"] || %{}, "address", [address | current_addresses])
        merged = Map.put(user, "attributes", new_attributes)
        Keycloak.update_user(keycloak_id, merged)
      end
    end
  end

  defp append_address_to_keycloak_user(_keycloak_id, _address), do: :ok

  defp update_identities(items, keycloak_map) do
    Enum.map(items, fn %{identity_id: id, auth0_id: auth0_id} ->
      with {:ok, keycloak_id} when is_binary(keycloak_id) <- Map.fetch(keycloak_map, id),
           :ok <- update_identity_uid(id, keycloak_id) do
        {:ok, auth0_id, keycloak_id}
      else
        :error ->
          Logger.error("No Keycloak ID for identity #{id} (#{auth0_id})")
          {:error, auth0_id, :no_keycloak_id}

        {:ok, nil} ->
          Logger.error("No Keycloak ID for identity #{id} (#{auth0_id})")
          {:error, auth0_id, :no_keycloak_id}

        {:error, reason} ->
          Logger.error("Failed to update identity #{id}: #{inspect(reason)}")
          {:error, auth0_id, reason}
      end
    end)
  end

  defp update_identity_uid(id, keycloak_id) do
    case Repo.account_repo().get(Identity, id) do
      nil ->
        {:error, "Identity #{id} not found"}

      identity ->
        identity
        |> Identity.changeset(%{uid: keycloak_id})
        |> Repo.account_repo().update()
        |> case do
          {:ok, _} -> :ok
          {:error, changeset} -> {:error, "Update failed: #{inspect(changeset.errors)}"}
        end
    end
  end

  defp delete_non_migrated_identities(protected_ids) do
    protected_id_list = MapSet.to_list(protected_ids)

    query =
      if Enum.empty?(protected_id_list) do
        from(i in Identity)
      else
        from(i in Identity, where: i.id not in ^protected_id_list)
      end

    {deleted, _} = Repo.account_repo().delete_all(query)
    Logger.info("Deleted #{deleted} non-migrated identities (cascading to their associated data)")
  end

  defp keycloak_partial_import(users) do
    body = %{ifResourceExists: "SKIP", users: users}

    with {:ok, token} <- get_keycloak_admin_token() do
      url = keycloak_url("/admin/realms/#{URI.encode(keycloak_realm())}/partialImport")

      case HttpClient.post(url, Jason.encode!(body), keycloak_auth_headers(token) ++ @json_headers) do
        {:ok, %{status_code: 200, body: resp_body}} ->
          Jason.decode(resp_body)

        {:ok, %{status_code: status, body: resp_body}} ->
          {:error, "HTTP #{status}: #{resp_body}"}

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  # Caches the admin token in the process dictionary for the duration of the migration.
  defp get_keycloak_admin_token do
    case Process.get(:keycloak_admin_token) do
      {token, expires_at} when is_integer(expires_at) and expires_at > 0 ->
        if System.system_time(:second) < expires_at do
          {:ok, token}
        else
          fetch_keycloak_admin_token()
        end

      _ ->
        fetch_keycloak_admin_token()
    end
  end

  defp fetch_keycloak_admin_token do
    url = keycloak_url("/realms/#{URI.encode(keycloak_realm())}/protocol/openid-connect/token")

    body =
      URI.encode_query(%{
        grant_type: "client_credentials",
        client_id: keycloak_client_id(),
        client_secret: keycloak_client_secret()
      })

    case HttpClient.post(url, body, [{"content-type", "application/x-www-form-urlencoded"}]) do
      {:ok, %{status_code: 200, body: resp_body}} ->
        case Jason.decode(resp_body) do
          {:ok, %{"access_token" => token, "expires_in" => ttl}} ->
            Process.put(:keycloak_admin_token, {token, System.system_time(:second) + ttl - 30})
            {:ok, token}

          _ ->
            {:error, "Invalid Keycloak token response"}
        end

      error ->
        {:error, "Failed to get Keycloak admin token: #{inspect(error)}"}
    end
  end

  defp keycloak_auth_headers(token), do: [{"authorization", "Bearer #{token}"}]

  defp keycloak_url(path) do
    keycloak_domain()
    |> URI.parse()
    |> URI.append_path(path)
    |> URI.to_string()
  end

  defp disable_account do
    Logger.info("Disabling account access for migration")
    update_account_enabled(false)
  end

  defp enable_account do
    update_account_enabled(true)
  end

  defp update_account_enabled(enabled) do
    config = Application.get_env(:explorer, Account, [])
    Application.put_env(:explorer, Account, Keyword.put(config, :enabled, enabled))
  end

  defp disable_auth0 do
    config = Application.get_env(:ueberauth, OAuth, [])
    Application.put_env(:ueberauth, OAuth, Keyword.put(config, :domain, nil))
  end

  defp finalize(results, protected_ids) do
    failed = Enum.count(results, &match?({:error, _, _}, &1))

    if failed == 0 do
      Logger.info("Phase 5: Deleting non-migrated identities...")
      delete_non_migrated_identities(protected_ids)

      disable_auth0()
      invalidate_all_sessions()
      enable_account()
      Logger.info("Migration successful. Auth0 disabled, Keycloak is now the active auth provider.")
    else
      Logger.warning(
        "Migration had #{failed} failures. Account access remains DISABLED. " <>
          "Review errors and re-run, or manually enable account access."
      )
    end
  end

  # Invalidates all user sessions by removing their Redis validation keys.
  # Session cookies are signed but validated against Redis on each request.
  # Without the Redis key, the cookie is rejected and the user must re-authenticate.
  defp invalidate_all_sessions do
    Logger.info("Invalidating all user sessions...")
    chain_id = chain_id()
    pattern = if chain_id, do: "#{chain_id}_*", else: "*"
    count = scan_and_delete(pattern)
    Logger.info("Invalidated #{count} session keys from Redis")
  end

  defp scan_and_delete(pattern, cursor \\ "0", count \\ 0) do
    case Redix.command(:redix, ["SCAN", cursor, "MATCH", pattern, "COUNT", 1000]) do
      {:ok, [next_cursor, keys]} ->
        unless keys == [], do: Redix.command(:redix, ["DEL" | keys])
        new_count = count + length(keys)

        if next_cursor == "0" do
          new_count
        else
          scan_and_delete(pattern, next_cursor, new_count)
        end

      error ->
        Logger.error("Redis SCAN failed: #{inspect(error)}")
        count
    end
  end

  defp summarize(results) do
    succeeded = Enum.count(results, &match?({:ok, _, _}, &1))
    failed = Enum.count(results, &match?({:error, _, _}, &1))
    Logger.info("Migration complete: #{succeeded} succeeded, #{failed} failed, #{succeeded + failed} total")
  end

  defp log_dry_run_deletion_count(protected_ids) do
    total_count = Repo.account_repo().aggregate(Identity, :count)

    would_delete = total_count - MapSet.size(protected_ids)

    Logger.info(
      "[DRY RUN] Would delete #{would_delete} non-migrated identities " <>
        "(#{total_count} total, #{MapSet.size(protected_ids)} protected)"
    )
  end

  defp log_dry_run(items) do
    Enum.each(items, fn item ->
      identity_label = if Map.has_key?(item, :identity_id), do: "Identity #{item.identity_id}: ", else: ""

      Logger.info(
        "[DRY RUN] #{identity_label}#{item.auth0_id} -> " <>
          "email=#{inspect(item.email)}, address=#{inspect(item.address)}, " <>
          "username=#{item.username}, has_user_data=#{item.has_user_data}"
      )
    end)
  end
end
