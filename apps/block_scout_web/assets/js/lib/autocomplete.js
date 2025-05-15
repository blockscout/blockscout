import $ from 'jquery'
// @ts-ignore
import AutoComplete from '@tarekraafat/autocomplete.js/dist/autoComplete'
import { getTextAdData, fetchTextAdData } from './ad'
import { DateTime } from 'luxon'
import { appendTokenIcon } from './token_icon'
import { escapeHtml } from './utils'
import { commonPath } from './path_helper'
import xss from 'xss'

const placeHolder = 'Search by address, token symbol, name, transaction hash, or block number'
const dataSrc = async (query, id) => {
  try {
    // Loading placeholder text
    const searchInput = document
      .getElementById(id)

    searchInput && searchInput.setAttribute('placeholder', 'Loading...')

    // Fetch External Data Source
    const source = await fetch(
      `${commonPath}/token-autocomplete?q=${query}`
    )
    const data = await source.json()
    // Post Loading placeholder text

    searchInput && searchInput.setAttribute('placeholder', placeHolder)
    // Returns Fetched data
    return data
  } catch (error) {
    return error
  }
}
const resultsListElement = (list, data) => {
  const info = document.createElement('p')
  const adv = `
  <div class="ad mb-3" style="display: none;">
  <span class='ad-prefix'></span>: <img class="ad-img-url" width=20 height=20 /> <b><span class="ad-name"></span></b> - <span class="ad-short-description"></span> <a class="ad-url"><b><span class="ad-cta-button"></span></a></b>
  </div>`
  info.innerHTML = adv
  if (data.results.length > 0) {
    info.innerHTML += `Displaying <strong>${data.results.length}</strong> results`
  } else if (data.query !== '###') {
    info.innerHTML += `Found <strong>${data.matches.length}</strong> matching results for `
    const strong = document.createElement('strong')
    strong.appendChild(document.createTextNode(data.query))
    info.appendChild(strong)
  }

  list.prepend(info)

  fetchTextAdData()
}
export const searchEngine = (query, record) => {
  const queryLowerCase = query.toLowerCase()
  if (record && (
    (record.name && record.name.toLowerCase().includes(queryLowerCase)) ||
      (record.symbol && record.symbol.toLowerCase().includes(queryLowerCase)) ||
      (record.address_hash && record.address_hash.toLowerCase().includes(queryLowerCase)) ||
      (record.tx_hash && record.tx_hash.toLowerCase().includes(queryLowerCase)) ||
      (record.block_hash && record.block_hash.toLowerCase().includes(queryLowerCase))
  )
  ) {
    let searchResult = '<div>'
    searchResult += `<div>${record.address_hash || record.tx_hash || record.block_hash}</div>`

    if (record.type === 'label') {
      searchResult += `<div class="fontawesome-icon tag"></div><span> <b>${record.name}</b></span>`
    } else {
      searchResult += '<div>'
      if (record.name) {
        searchResult += `<b>${escapeHtml(record.name)}</b>`
      }
      if (record.symbol) {
        searchResult += ` (${escapeHtml(record.symbol)})`
      }
      if (record.holder_count) {
        searchResult += ` <i>${record.holder_count} holder(s)</i>`
      }
      if (record.inserted_at) {
        searchResult += ` (${DateTime.fromISO(record.inserted_at).toLocaleString(DateTime.DATETIME_SHORT)})`
      }
      searchResult += '</div>'
    }
    searchResult += '</div>'
    const re = new RegExp(query, 'ig')
    searchResult = searchResult.replace(re, '<mark class=\'autoComplete_highlight\'>$&</mark>')
    return searchResult
  }
}
const resultItemElement = async (item, data) => {
  item.style = 'display: flex;'

  item.innerHTML = `
  <div id='token-icon-${data.value.address_hash}' style='margin-top: -1px;'></div>
  <div style="padding-left: 10px; padding-right: 10px; text-overflow: ellipsis; white-space: nowrap; overflow: hidden;">
    ${data.match}
  </div>
  <div class="autocomplete-category">
    ${data.value.type}
  </div>`

  const $tokenIconContainer = $(item).find(`#token-icon-${data.value.address_hash}`)
  const $searchInput = $('#main-search-autocomplete')
  const chainID = $searchInput.data('chain-id')
  const displayTokenIcons = $searchInput.data('display-token-icons')
  appendTokenIcon($tokenIconContainer, chainID, data.value.address_hash, displayTokenIcons, 15)
}
const config = (id) => {
  return {
    selector: `#${id}`,
    data: {
      src: (query) => dataSrc(query, id),
      cache: false
    },
    placeHolder,
    searchEngine: (query, record) => searchEngine(query, record),
    threshold: 2,
    resultsList: {
      element: (list, data) => resultsListElement(list, data),
      noResults: true,
      maxResults: 100,
      tabSelect: true
    },
    resultItem: {
      element: (item, data) => resultItemElement(item, data),
      highlight: 'autoComplete_highlight'
    },
    query: (input) => {
      return xss(input)
    },
    events: {
      input: {
        focus: () => {
          // @ts-ignore
          if (autoCompleteJS && autoCompleteJS.input.value.length) autoCompleteJS.start()
        }
      }
    }
  }
}
const autoCompleteJS = document.querySelector('#main-search-autocomplete') && new AutoComplete(config('main-search-autocomplete'))
 
const autoCompleteJSMobile = document.querySelector('#main-search-autocomplete-mobile') && new AutoComplete(config('main-search-autocomplete-mobile'))

const selection = (event) => {
  const selectionValue = event.detail.selection.value

  if (selectionValue.type === 'contract' || selectionValue.type === 'address' || selectionValue.type === 'label') {
    window.location.href = `${commonPath}/address/${selectionValue.address_hash}`
  } else if (selectionValue.type === 'token') {
    window.location.href = `${commonPath}/tokens/${selectionValue.address_hash}`
  } else if (selectionValue.type === 'transaction') {
    window.location.href = `${commonPath}/tx/${selectionValue.tx_hash}`
  } else if (selectionValue.type === 'block') {
    window.location.href = `${commonPath}/blocks/${selectionValue.block_hash}`
  }
}

const openOnFocus = (event, type) => {
  const query = event.target.value
  if (query) {
    if (type === 'desktop') {
      // @ts-ignore
      autoCompleteJS && autoCompleteJS.start(query)
    } else if (type === 'mobile') {
      // @ts-ignore
      autoCompleteJSMobile && autoCompleteJSMobile.start(query)
    }
  } else {
    getTextAdData()
      .then(({ data: adData, inHouse: _inHouse }) => {
        if (adData) {
          if (type === 'desktop') {
            // @ts-ignore
            autoCompleteJS && autoCompleteJS.start('###')
          } else if (type === 'mobile') {
            // @ts-ignore
            autoCompleteJSMobile && autoCompleteJSMobile.start('###')
          }
        }
      })
  }
}

const mainSearchAutocompleteObj = document.querySelector('#main-search-autocomplete')
const mainSearchAutocompleteMobileObj = document.querySelector('#main-search-autocomplete-mobile')

mainSearchAutocompleteObj && mainSearchAutocompleteObj.addEventListener('selection', function (event) {
  selection(event)
})
mainSearchAutocompleteMobileObj && mainSearchAutocompleteMobileObj.addEventListener('selection', function (event) {
  selection(event)
})
mainSearchAutocompleteObj && mainSearchAutocompleteObj.addEventListener('focus', function (event) {
  openOnFocus(event, 'desktop')
})
mainSearchAutocompleteMobileObj && mainSearchAutocompleteMobileObj.addEventListener('focus', function (event) {
  openOnFocus(event, 'mobile')
})
