import AutoComplete from '@tarekraafat/autocomplete.js/dist/autoComplete.js'
import { getTextAdData, fetchTextAdData } from './ad.js'
import { DateTime } from 'luxon'

const placeHolder = 'Search by address, token symbol, name, transaction hash, or block number'
const dataSrc = async (query, id) => {
  try {
    // Loading placeholder text
    const searchInput = document
      .getElementById(id)

    searchInput.setAttribute('placeholder', 'Loading...')

    // Fetch External Data Source
    const source = await fetch(
      `/token-autocomplete?q=${query}`
    )
    const data = await source.json()
    // Post Loading placeholder text

    searchInput.setAttribute('placeholder', placeHolder)
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
    info.innerHTML += `Found <strong>${data.matches.length}</strong> matching results for <strong>"${data.query}"</strong>`
  }

  list.prepend(info)

  fetchTextAdData()
}
const searchEngine = (query, record) => {
  if (record && (
    (record.name && record.name.toLowerCase().includes(query.toLowerCase())) ||
      (record.symbol && record.symbol.toLowerCase().includes(query.toLowerCase())) ||
      (record.contract_address_hash && record.contract_address_hash.toLowerCase().includes(query.toLowerCase())) ||
      (record.transaction_hash && record.transaction_hash.toLowerCase().includes(query.toLowerCase())) ||
      (record.address_hash && record.address_hash.toLowerCase().includes(query.toLowerCase())) ||
      (record.block_hash && record.block_hash.toLowerCase().includes(query.toLowerCase()))
  )
  ) {
    var searchResult = ''
    if (record.type === 'transaction') {
      searchResult += `${record.transaction_hash}<br/>`
    } else if (record.type === 'address') {
      searchResult += `${record.address_hash}<br/>`
    } else if (record.type === 'block') {
      searchResult += `${record.block_hash}<br/>`
    } else {
      searchResult += `${record.contract_address_hash}<br/>`
    }

    if (record.type === 'label') {
      searchResult += `<div class="fontawesome-icon tag"></div><span> <b>${record.name}</b></span>`
    } else {
      if (record.name) {
        searchResult += `<b>${record.name}</b>`
      }
      if (record.symbol) {
        searchResult += ` (${record.symbol})`
      }
      if (record.holder_count) {
        searchResult += ` <i>${record.holder_count} holder(s)</i>`
      }
      if (record.inserted_at) {
        searchResult += ` (${DateTime.fromISO(record.inserted_at).toLocaleString(DateTime.DATETIME_SHORT)})`
      }
    }
    var re = new RegExp(query, 'ig')
    searchResult = searchResult.replace(re, '<mark class=\'autoComplete_highlight\'>$&</mark>')
    return searchResult
  }
}
const resultItemElement = (item, data) => {
  // Modify Results Item Style
  item.style = 'display: flex; justify-content: space-between;'
  // Modify Results Item Content
  item.innerHTML = `
  <span style="text-overflow: ellipsis; white-space: nowrap; overflow: hidden;">
    ${data.match}
  </span>
  <span class="autocomplete-category">
    ${data.value.type}
  </span>`
}
const config = (id) => {
  return {
    selector: `#${id}`,
    data: {
      src: (query) => dataSrc(query, id),
      cache: false
    },
    placeHolder: placeHolder,
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
    events: {
      input: {
        focus: () => {
          if (autoCompleteJS.input.value.length) autoCompleteJS.start()
        }
      }
    }
  }
}
const autoCompleteJS = new AutoComplete(config('main-search-autocomplete'))
// eslint-disable-next-line
const autoCompleteJSMobile = new AutoComplete(config('main-search-autocomplete-mobile'))

const selection = (event) => {
  const selectionValue = event.detail.selection.value

  if (selectionValue.symbol) {
    window.location = `/tokens/${selectionValue.contract_address_hash}`
  } else {
    window.location = `/address/${selectionValue.contract_address_hash}`
  }
}

document.querySelector('#main-search-autocomplete').addEventListener('selection', function (event) {
  selection(event)
})
document.querySelector('#main-search-autocomplete-mobile').addEventListener('selection', function (event) {
  selection(event)
})

const openOnFocus = (event, type) => {
  const query = event.target.value
  if (query) {
    if (type === 'desktop') {
      autoCompleteJS.start(query)
    } else if (type === 'mobile') {
      autoCompleteJSMobile.start(query)
    }
  } else {
    getTextAdData()
      .then(({ data: adData, inHouse: _inHouse }) => {
        if (adData) {
          if (type === 'desktop') {
            autoCompleteJS.start('###')
          } else if (type === 'mobile') {
            autoCompleteJSMobile.start('###')
          }
        }
      })
  }
}

document.querySelector('#main-search-autocomplete').addEventListener('focus', function (event) {
  openOnFocus(event, 'desktop')
})

document.querySelector('#main-search-autocomplete-mobile').addEventListener('focus', function (event) {
  openOnFocus(event, 'mobile')
})
