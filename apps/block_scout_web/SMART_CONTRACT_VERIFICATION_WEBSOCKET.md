# Smart Contract Verification Websocket Events

This guide explains how to subscribe to websocket notifications related to smart contract verification.

It covers:
- verification result notifications
- automated source lookup lifecycle notifications
- legacy and V2 websocket namespaces

## 1. Which Socket To Use

Blockscout exposes two websocket endpoints:

- Legacy UI socket: `/socket`
- V2 socket: `/socket/v2`

For new integrations, use the V2 socket.

## 2. Topic Format

Subscribe to an address topic.

- Legacy topic: `addresses_old:<address_hash>`
- V2 topic: `addresses:<address_hash>`

Examples:
- `addresses_old:0xabc123...`
- `addresses:0xabc123...`

The join validates the address hash and access restrictions. Join may fail with:
- `Invalid address hash`
- `Restricted access`

## 3. Events You Can Receive

### 3.1 `verification_result`

Purpose:
- Final result of a verification attempt (success or validation errors).

Emitted to topics:
- `addresses:<address_hash>`
- `addresses_old:<address_hash>`

Broadcast type in event bus:
- `:on_demand`

#### V2 payload

Success:

```json
{
  "status": "success"
}
```

Error:

```json
{
  "status": "error",
  "errors": {
    "field_name": [
      "error message"
    ]
  }
}
```

Notes:
- `errors` is generated from changeset errors.
- Field names and messages depend on verification flow and validator results.

#### Legacy behavior

Legacy notifier broadcasts an internal payload with `result`, but the legacy address channel intercepts `verification_result` and pushes event `verification` to clients.

Legacy client-facing event:
- `verification`

Legacy client payload:

```json
{
  "verification_result": "ok"
}
```

or

```json
{
  "verification_result": "<rendered html error block>"
}
```

Important legacy nuance:
- If the intercepted result is `{:error, %Ecto.Changeset{}}`, the channel does not push a websocket message for that event.

### 3.2 `eth_bytecode_db_lookup_started`

Purpose:
- Signals that automated lookup in Ethereum Bytecode DB started.

Emitted to topics:
- `addresses:<address_hash>`
- `addresses_old:<address_hash>`

Payload:

```json
{}
```

### 3.3 `smart_contract_was_verified`

Purpose:
- Signals that automated lookup/verification finished with a verified result.

Emitted to topics:
- `addresses:<address_hash>`
- `addresses_old:<address_hash>`

Payload:

```json
{}
```

### 3.4 `smart_contract_was_not_verified`

Purpose:
- Signals that automated lookup/verification finished without verification.

Emitted to topics:
- `addresses:<address_hash>`
- `addresses_old:<address_hash>`

Payload:

```json
{}
```

## 4. Event Producers (Server-Side)

### `contract_verification_result` chain event

Produced by verification workers/helpers and then mapped to websocket `verification_result`:
- Solidity verification worker
- Vyper verification worker
- Stylus verification worker
- Solidity publish helper (including some error paths)

### Automated source lookup lifecycle chain events

Produced by on-demand source lookup fetcher and mapped 1:1 to websocket event names:
- `eth_bytecode_db_lookup_started`
- `smart_contract_was_verified`
- `smart_contract_was_not_verified`

## 5. Subscription Example (Phoenix JS)

### V2 (recommended)

```javascript
import { Socket } from "phoenix";

const socket = new Socket("https://your-blockscout.example/socket/v2", {
  params: {}
});

socket.connect();

const addressHash = "0x...";
const channel = socket.channel(`addresses:${addressHash}`, {});

channel
  .join()
  .receive("ok", () => console.log("joined"))
  .receive("error", (err) => console.error("join failed", err));

channel.on("verification_result", (payload) => {
  // { status: "success" } OR { status: "error", errors: {...} }
  console.log("verification_result", payload);
});

channel.on("eth_bytecode_db_lookup_started", () => {
  console.log("lookup started");
});

channel.on("smart_contract_was_verified", () => {
  console.log("verified via automatic lookup");
});

channel.on("smart_contract_was_not_verified", () => {
  console.log("not verified via automatic lookup");
});
```

### Legacy

```javascript
import { Socket } from "phoenix";

const socket = new Socket("https://your-blockscout.example/socket", {
  params: { locale: "en" }
});

socket.connect();

const addressHash = "0x...";
const channel = socket.channel(`addresses_old:${addressHash}`, {});

channel.join();

// Legacy verification result event name is "verification"
channel.on("verification", (payload) => {
  // payload.verification_result is "ok" or rendered html error string
  console.log("verification", payload);
});

// Automatic lookup lifecycle events are forwarded with original names
channel.on("eth_bytecode_db_lookup_started", () => {
  console.log("lookup started");
});

channel.on("smart_contract_was_verified", () => {
  console.log("verified");
});

channel.on("smart_contract_was_not_verified", () => {
  console.log("not verified");
});
```

## 6. Practical Client Flow

Recommended for automation clients:

1. Submit verification request via HTTP API.
2. Immediately subscribe to `addresses:<address_hash>` on `/socket/v2`.
3. Wait for `verification_result` for final API-style outcome.
4. Optionally track automated lookup lifecycle with:
   - `eth_bytecode_db_lookup_started`
   - `smart_contract_was_verified`
   - `smart_contract_was_not_verified`

Notes:
- API response like "verification started" means the job was accepted, not completed.
- Final state should be taken from websocket events.
- Server currently broadcasts to both legacy and V2 address namespaces for backward compatibility.
