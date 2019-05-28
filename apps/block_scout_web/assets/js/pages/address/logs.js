import $ from 'jquery'
import _ from 'lodash'
import URI from 'urijs'
import humps from 'humps'
import { subscribeChannel } from '../../socket'
import { connectElements } from '../../lib/redux_helpers.js'
import { createAsyncLoadStore } from '../../lib/async_listing_load'

export const initialState = {
    addressHash: null
}

export function reducer (state, action) {
    switch (action.type) {
    case 'PAGE_LOAD':
    case 'ELEMENTS_LOAD': {
        return Object.assign({}, state, _.omit(action, 'type'))
    }
    default:
        return state
    }
}

const elements = {
    '[data-search-field]' : {
        render ($el, state) {
            $el
        }
    },
    '[data-search-button]' : {
        render ($el, state) {
            $el
        }
    }
}

if ($('[data-page="address-logs"]').length) {
    console.log('iffff')
    const store = createAsyncLoadStore(reducer, initialState, 'dataset.identifierHash')
    const addressHash = $('[data-page="address-details"]')[0].dataset.pageAddressHash
    const $element = $('[data-async-listing]')


    connectElements({ store, elements })

    store.dispatch({
        type: 'PAGE_LOAD',
        addressHash: addressHash})

    function loadSearchItems () {
        var topic = $('[data-search-field]').val();
        var path = "/search_logs?topic=" + topic + "&address_id=" + store.getState().addressHash
        store.dispatch({type: 'START_REQUEST'})
        $.getJSON(path, {type: 'JSON'})
            .done(response => store.dispatch(Object.assign({type: 'ITEMS_FETCHED'}, humps.camelizeKeys(response))))
            .fail(() => store.dispatch({type: 'REQUEST_ERROR'}))
            .always(() => store.dispatch({type: 'FINISH_REQUEST'}))
    }


    $element.on('click', '[data-search-button]', (event) => {
        loadSearchItems()
    })
}
