import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class L1RelayedMessageEvents {
  @Column({ type: 'bytea' })
  tx_hash: string;

  @Column({ type: 'bigint' })
  block_number: string;

  @PrimaryColumn({ type: 'bytea' })
  msg_hash: string;

  @Column({ type: 'bytea' })
  signature: string;

  @Column({ type: 'boolean' })
  is_merge: boolean;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  updated_at: Date;
}
