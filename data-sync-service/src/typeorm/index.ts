import { L1ToL2 } from "./l1_to_l2.entity";
import { L2ToL1 } from "./l2_to_l1.entity";
import { L1RelayedMessageEvents } from "./l1_relayed_message_events.entity";
import { L1SentMessageEvents } from "./l1_sent_message_events.entity";
import { L2RelayedMessageEvents } from "./l2_relayed_message_events.entity";
import { L2SentMessageEvents } from "./l2_sent_message_events.entity";
import { StateBatches } from "./state_batches.entity";
import { TxnBatches } from "./txn_batches.entity";


const entities = [
    L1ToL2, L2ToL1,
    L1RelayedMessageEvents,
    L1SentMessageEvents,
    L2RelayedMessageEvents,
    L2SentMessageEvents,
    StateBatches,
    TxnBatches,
];

export {
    L1ToL2, L2ToL1,
    L1RelayedMessageEvents,
    L1SentMessageEvents,
    L2RelayedMessageEvents,
    L2SentMessageEvents,
    StateBatches,
    TxnBatches,
};
export default entities;