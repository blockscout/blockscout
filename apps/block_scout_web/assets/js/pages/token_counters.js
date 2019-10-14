import $ from "jquery";
import omit from "lodash/omit";
import URI from "urijs";
import humps from "humps";
import { subscribeChannel } from "../socket";
import { createStore, connectElements } from "../lib/redux_helpers.js";

export const initialState = {
  channelDisconnected: false,
  addressHash: null,
  counters: null
};

export function reducer(state = initialState, action) {
  switch (action.type) {
    case "PAGE_LOAD":
    case "ELEMENTS_LOAD": {
      return Object.assign({}, state, omit(action, "type"));
    }
    case "CHANNEL_DISCONNECTED": {
      if (state.beyondPageOne) return state;

      return Object.assign({}, state, {
        channelDisconnected: true
      });
    }
    case "RECEIVED_COUNTERS_RESULT": {
      return Object.assign({}, state, {
        counters: action.msg.counters
      });
    }
    default:
      return state;
  }
}

const elements = {
  '[data-selector="channel-disconnected-message"]': {
    render($el, state) {
      if (state.channelDisconnected) $el.show();
    }
  },
  '[data-page="counters"]': {
    render($el, state) {
      if (state.counters) {
        return $el;
      }
      return $el;
    }
  }
};

const $tokenPage = $('[data-page="token-page"]');

if ($tokenPage.length) {
  const store = createStore(reducer);
  const addressHash = $("#smart_contract_address_hash").val();
  const { filter, blockNumber } = humps.camelizeKeys(
    URI(window.location).query(true)
  );

  store.dispatch({
    type: "PAGE_LOAD",
    addressHash,
    filter,
    beyondPageOne: !!blockNumber
  });
  connectElements({ store, elements });

  const addressChannel = subscribeChannel(`addresses:${addressHash}`);

  addressChannel.onError(() =>
    store.dispatch({
      type: "CHANNEL_DISCONNECTED"
    })
  );
  addressChannel.on("token_counters", msg =>
    store.dispatch({
      type: "RECEIVED_COUNTERS_RESULT",
      msg: humps.camelizeKeys(msg)
    })
  );
}
