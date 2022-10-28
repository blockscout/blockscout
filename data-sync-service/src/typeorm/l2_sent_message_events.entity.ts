import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class L2SentMessageEvents {
  @Column({ type: "bytea" })
  tx_hash: string;

  @Column({ type: "bigint" })
  block_number: string;

  @Column({ type: "bytea" })
  target: string;

  @Column({ type: "bytea" })
  sender: string;

  @Column({ type: "bytea" })
  message: string;

  @Column({ type: "bytea" })
  signature: string;

  @PrimaryColumn({ type: 'numeric', precision: 100 })
  message_nonce: number;

  @Column({ type: 'numeric', precision: 100 })
  gas_limit: number;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  updated_at: Date;
}