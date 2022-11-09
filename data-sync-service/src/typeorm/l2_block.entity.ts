import { Column, Entity, PrimaryColumn } from 'typeorm';

@Entity()
export class L2Block {
  @PrimaryColumn({ type: 'bytea', name: 'chain' })
  @Column({ type: 'bytea' })
  chain: string;

  @Column({ type: 'int8' })
  l1_send_block: number;

  @Column({ type: 'int8' })
  l1_relay_block: number;

  @Column({ type: 'int8' })
  l2_send_block: number;

  @Column({ type: 'int8' })
  l2_relay_block: number;


  @Column({ type: "boolean" })
  active: boolean;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  inserted_at: Date;

  @Column({ type: 'timestamp', default: () => 'CURRENT_TIMESTAMP' })
  updated_at: Date;

}