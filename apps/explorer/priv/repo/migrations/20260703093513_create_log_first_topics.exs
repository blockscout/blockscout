defmodule Explorer.Repo.Migrations.CreateLogFirstTopics do
  use Ecto.Migration

  def change do
    create table(:log_first_topics) do
      add(:value, :bytea, null: false)

      timestamps(updated_at: false)
    end

    create(unique_index(:log_first_topics, [:value]))

    alter table(:logs) do
      add(:first_topic_id, references(:log_first_topics, validate: false))
    end

    execute("""
    INSERT INTO log_first_topics (id, value, inserted_at)
    VALUES
    (
        1,
        decode('ddf252ad1be2c89b69c2b068fc378daa952ba7f163c4a11628f55a4df523b3ef', 'hex'),
        NOW()
    ),
    (
        2,
        decode('e1fffcc4923d04b559f4d29a8bfc6cda04eb5b0d3c460751c2402c5c5cc9109c', 'hex'),
        NOW()
    ),
    (
        3,
        decode('7fcf532c15f0a6db0bd6d0e038bea71d30d808c7d98cb3bf7268a95bf5081b65', 'hex'),
        NOW()
    ),
    (
        4,
        decode('c3d58168c5ae7397731d063d5bbf3d657854427343f4c083240f7aacaa2d0f62', 'hex'),
        NOW()
    ),
    (
        5,
        decode('4a39dc06d4c0dbc64b70af90fd698a233a518aa5d07e595d983b8c0526c8f7fb', 'hex'),
        NOW()
    ),
    (
        6,
        decode('e59fdd36d0d223c0c7d996db7ad796880f45e1936cb0bb7ac102e7082e031487', 'hex'),
        NOW()
    ),
    (
        7,
        decode('e5f815dc84b8cecdfd4beedfc3f91ab5be7af100eca4e8fb11552b867995394f', 'hex'),
        NOW()
    ),
    (
        8,
        decode('62f084c00a442dcf51cdbb51beed2839bf42a268da8474b0e98f38edb7db5a22', 'hex'),
        NOW()
    ),
    (
        9,
        decode('b049859d09b3a7d0189a07db4d4becee1a2aa269023205478b1360ab6fc12114', 'hex'),
        NOW()
    ),
    (
        10,
        decode('aaf1ef013644e67c5cea90217acdf0accd334f8437fc9a89a53cfc9b25fb5c25', 'hex'),
        NOW()
    ),
    (
        11,
        decode('67500e8d0ed826d2194f514dd0d8124f35648ab6e3fb5e6ed867134cffe661e9', 'hex'),
        NOW()
    );
    """)

    execute("""
      SELECT setval(pg_get_serial_sequence('log_first_topics', 'id'), (SELECT MAX(id) FROM log_first_topics));
    """)
  end
end
