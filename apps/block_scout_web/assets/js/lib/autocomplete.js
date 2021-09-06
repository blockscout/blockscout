import AutoComplete from '@tarekraafat/autocomplete.js/dist/autoComplete.js'
import identicon from 'identicon'
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
      (record.address_hash && record.address_hash.toLowerCase().includes(query.toLowerCase())) ||
      (record.tx_hash && record.tx_hash.toLowerCase().includes(query.toLowerCase())) ||
      (record.block_hash && record.block_hash.toLowerCase().includes(query.toLowerCase()))
  )
  ) {
    var searchResult = '<div>'
    searchResult += `<div>${record.address_hash || record.tx_hash || record.block_hash}</div>`

    if (record.type === 'label') {
      searchResult += `<div class="fontawesome-icon tag"></div><span> <b>${record.name}</b></span>`
    } else {
      searchResult += '<div>'
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
      searchResult += '</div>'
    }
    searchResult += '</div>'
    var re = new RegExp(query, 'ig')
    searchResult = searchResult.replace(re, '<mark class=\'autoComplete_highlight\'>$&</mark>')
    return searchResult
  }
}
const resultItemElement = async (item, data) => {
  // Modify Results Item Style
  item.style = 'display: flex;'
  // Modify Results Item Content

  var innerHTML = ''
  var checkTokenIconLink = null
  var bridgedTokenIconURL = null
  if (data.value.foreign_token_hash) {
    bridgedTokenIconURL = getTokenIconUrl(data.value.foreign_chain_id, data.value.foreign_token_hash)
    if (bridgedTokenIconURL) {
      innerHTML = `
        <img height="40px" width="40px" src="${bridgedTokenIconURL}" />
      `
    } else {
      innerHTML = `<div id='identicon_${data.value.address_hash}'></div>`
    }
  } else if (data.value.type === 'token') {
    const tokenIconURL = getTokenIconUrl('77', data.value.address_hash)

    if (tokenIconURL) {
      const checkTokenIconLink = await checkLink(tokenIconURL)
      if (checkTokenIconLink) {
        innerHTML = `<img height="40px" width="40px" src="${tokenIconURL}" />`
      } else {
        innerHTML = `<div id='identicon_${data.value.address_hash}'></div>`
      }
    } else {
      innerHTML = `<div id='identicon_${data.value.address_hash}'></div>`
    }
  }
  innerHTML += `
  <div style="padding-left: 10px; padding-right: 10px; text-overflow: ellipsis; white-space: nowrap; overflow: hidden;">
    ${data.match}
  </div>
  <div class="autocomplete-category">
    ${data.value.type}
  </div>`
  item.innerHTML = innerHTML

  if (data.value.type === 'token' && ((!data.value.foreign_token_hash && !checkTokenIconLink) || (data.value.foreign_token_hash && !bridgedTokenIconURL))) {
    identicon.generate({ id: data.value.address_hash, size: 40 }, function (err, buffer) {
      if (err) throw err

      var img = new Image()
      img.src = buffer
      const identiconTarget = item.querySelector(`#identicon_${data.value.address_hash}`)
      if (identiconTarget) {
        identiconTarget.appendChild(img)
      }
    })
  }
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

  if (selectionValue.type === 'contract' || selectionValue.type === 'address' || selectionValue.type === 'label') {
    window.location = `/address/${selectionValue.address_hash}`
  } else if (selectionValue.type === 'token') {
    window.location = `/tokens/${selectionValue.address_hash}`
  } else if (selectionValue.type === 'transaction') {
    window.location = `/tx/${selectionValue.tx_hash}`
  } else if (selectionValue.type === 'block') {
    window.location = `/blocks/${selectionValue.block_hash}`
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

async function checkLink (url) {
  try {
    const res = await fetch(url)
    return res.ok
  } catch (_error) {
    return false
  }
}

function getTokenIconUrl (chainID, addressHash) {
  var chainName = null
  switch (chainID) {
    case '1':
      chainName = 'ethereum'
      break
    case '99':
      chainName = 'poa'
      break
    case '100':
      chainName = 'xdai'
      break
    default:
      chainName = null
      break
  }
  if (chainName) {
    return `https://raw.githubusercontent.com/trustwallet/assets/master/blockchains/${chainName}/assets/${addressHash}/logo.png`
  } else {
    return null
  }
}
