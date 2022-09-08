import { Addresses } from "./addresses.entity";
import { Transactions } from "./transactions.entity";
import { L1ToL2 } from "./l1_to_l2.entity";
import { L2ToL1 } from "./l2_to_l1.entity";
import { TxnBatches } from "./txn_batches.entity";
import { StateBatches } from "./state_batches.entity";

const entities = [Addresses, Transactions, L1ToL2, L2ToL1, TxnBatches, StateBatches];

export {Addresses, Transactions, L1ToL2, L2ToL1, TxnBatches, StateBatches};
export default entities;