import $ from 'jquery'
import _ from 'lodash'
import humps from 'humps'
import numeral from 'numeral'
import socket from '../socket'
import {
    connectElements
} from '../lib/redux_helpers'
import {
    createAsyncLoadStore
} from '../lib/async_listing_load'
import {
    batchChannel
} from '../lib/utils'

export const initialState = {
    channelDisconnected: false,
    attestationCount: null,
    vanityCount: null
}

export function reducer(state = initialState, action) {
    switch (action.type) {
        case 'DISPLAY_ATTESTATION_STATS':
            {
                const attestationCount = state.attestationCount
                return Object.assign({}, state, attestationCount)
            }

        case 'DISPLAY_VANITY_STATS':
            {
                const vanityCount = state.vanityCount
                return Object.assign({}, state, vanityCount)
            }

    }
}

const elements = {
    '[data-selector="attestation-transaction-count"]': {
        load($el) {
            return {
                attestationCount: numeral($el.text()).value()
            }
        },
        render($el, state) {
            return $el.empty().append(numeral(state.attestationCount).format())
        }
    },

    '[data-selector="vanity-transaction-count"]': {
        load($el) {
            return {
                vanityCount: numeral($el.text()).value()
            }
        },
        render($el, state) {
            return $el.empty().append(numeral(state.vanityCount).format())
        }
    }
}