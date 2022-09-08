import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class L1ToL2 {
  @PrimaryColumn({ type: "bytea", name: 'hash' })
  hash: string;

  @Column({ type: "bytea" })
  l2_hash: string;

  @Column({ type: "int8" })
  block: number;

  @Column({ type: 'timestamp' })
  timestamp: Date;

  @Column({ type: 'bytea' })
  tx_origin: Date;

  @Column({ type: "int8" })
  queue_index: number;

  @Column({ type: 'bytea' })
  data: string;

  @Column({ type: 'bytea' })
  target: string;

  @Column({ type: 'numeric', precision: 100 })
  gas_limit: number;
  
  @Column({ type: 'numeric', precision: 100 })
  gas_used: number;

  @Column({ type: 'numeric', precision: 100 })
  gas_price: number;
  
  @Column({ type: "int8" })
  fee_scalar: number;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => "CURRENT_TIMESTAMP"})
  updated_at: Date;
  
}