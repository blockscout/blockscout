defmodule Explorer.Repo.Account.Migrations.CopyAccountData do
  use Ecto.Migration

  def change do
    execute("CREATE EXTENSION dblink;")
    execute("SELECT dblink_connect('db_to_copy_from', '#{System.get_env("DATABASE_URL")}');")

    execute(
      "INSERT INTO account_identities
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_identities')
          row(id bigint, uid character varying(255), inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone, email character varying(255), name character varying(255), plan_id bigint, nickname character varying(255), avatar text);"
    )

    # execute("INSERT INTO account_api_plans
    #     SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_api_plans')
    #       row(id integer, max_req_per_second smallint, name character varying(255), inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);")

    execute(
      "INSERT INTO account_api_keys
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_api_keys') 
          row(identity_id bigint, name character varying(255), value uuid, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);"
    )

    execute(
      "INSERT INTO account_custom_abis
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_custom_abis')
          row(id integer, identity_id bigint, name character varying(255), address_hash bytea, abi jsonb, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);"
    )

    execute(
      "INSERT INTO account_public_tags_requests
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_public_tags_requests')
          row(id integer, identity_id bigint, full_name character varying(255), email character varying(255), company character varying(255), website character varying(255), tags character varying(255), description text, additional_comment character varying(255), request_type character varying(255), is_owner boolean, remove_reason text, request_id character varying(255), inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone, addresses bytea[]);"
    )

    execute(
      "INSERT INTO account_tag_addresses
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_tag_addresses')
          row(id integer, name character varying(255), identity_id bigint, address_hash bytea, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);"
    )

    execute(
      "INSERT INTO account_tag_transactions
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_tag_transactions')
          row(id integer, name character varying(255), identity_id bigint, tx_hash bytea, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);"
    )

    execute(
      "INSERT INTO account_watchlists
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_watchlists')
          row(id bigint, name character varying(255), identity_id bigint, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);"
    )

    execute(
      "INSERT INTO account_watchlist_addresses
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_watchlist_addresses')
          row(id bigint, name character varying(255), address_hash bytea, watchlist_id bigint, watch_coin_input boolean, watch_coin_output boolean, watch_erc_20_input boolean, watch_erc_20_output boolean, watch_erc_721_input boolean, watch_erc_721_output boolean, watch_erc_1155_input boolean, watch_erc_1155_output boolean, notify_email boolean, notify_epns boolean, notify_feed boolean, notify_inapp boolean, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);"
    )

    execute(
      "INSERT INTO account_watchlist_notifications
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM account_watchlist_notifications')
          row(id bigint, watchlist_address_id bigint, transaction_hash bytea, from_address_hash bytea, to_address_hash bytea, direction character varying(255), name character varying(255), type character varying(255), method character varying(255), block_number integer, amount numeric, tx_fee numeric, viewed_at timestamp without time zone, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone, subject character varying(255));"
    )

    execute(
      "INSERT INTO guardian_tokens
        SELECT * FROM dblink('db_to_copy_from', 'SELECT * FROM guardian_tokens')
          row(jti character varying(255), aud character varying(255), typ character varying(255), iss character varying(255), sub character varying(255), exp bigint, jwt text, claims jsonb, inserted_at timestamp(0) without time zone, updated_at timestamp(0) without time zone);"
    )

    execute("SELECT dblink_disconnect('db_to_copy_from');")
    execute("DROP EXTENSION dblink;")

    # update sequence id counter
    execute("SELECT setval('account_identities_id_seq', (SELECT MAX(id) FROM account_identities)+1);")
    execute("SELECT setval('account_custom_abis_id_seq', (SELECT MAX(id) FROM account_custom_abis)+1);")

    execute(
      "SELECT setval('account_public_tags_requests_id_seq', (SELECT MAX(id) FROM account_public_tags_requests)+1);"
    )

    execute("SELECT setval('account_tag_addresses_id_seq', (SELECT MAX(id) FROM account_tag_addresses)+1);")
    execute("SELECT setval('account_tag_transactions_id_seq', (SELECT MAX(id) FROM account_tag_transactions)+1);")
    execute("SELECT setval('account_watchlists_id_seq', (SELECT MAX(id) FROM account_watchlists)+1);")
    execute("SELECT setval('account_watchlist_addresses_id_seq', (SELECT MAX(id) FROM account_watchlist_addresses)+1);")

    execute(
      "SELECT setval('account_watchlist_notifications_id_seq', (SELECT MAX(id) FROM account_watchlist_notifications)+1);"
    )
  end
end
