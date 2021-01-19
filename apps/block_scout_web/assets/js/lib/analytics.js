// import { createStore } from './redux_helpers.js'

// import $ from 'jquery'
import Analytics from 'analytics'
// import omit from 'lodash/omit'

const analytics = Analytics({
  app: 'Blockscout',
  plugins: [
    segmentPlugin({
      writeKey: 'WRITE_KEY'
    })
  ]
})
analytics.page()

// // TODO: create unique user ID and save in store
// export const initialState = {
//   userID: '1'
// }

// export function reducer (state = initialState, action) {
//   switch (action.type) {
//     case 'PAGE_LOAD':
//     case 'ELEMENTS_LOAD': {
//       return Object.assign({}, state, omit(action, 'type'))
//     }
//     case 'SET_USER_ID': {
//       localStorage.setItem('userID', '2')
//       return Object.assign({}, state, { userID: '2' })
//     }
//     default:
//       return state
//   }
// }
// console.log('hi')

// const $app = $('[data-page="app-container"]')
// if ($app.length) {
//   const store = createStore(reducer)
//   init()
// }

// function init () {
//   if (!state.userID) {
//     // set id
//   }
//   analytics.identify(state.userID)
//   analytics.page()
//   trackEvents()
// }

// function trackEvents () {
//   // Page navigation

//   // Search box click
//   $('[data-selector="search-bar"]').on('click', function() {
//     analytics.track('search bar click')
//   })

//   // Search submit
//   $(function() {
//     $('[data-selector="search-bar"]').on('submit', function(e) {
//       e.preventDefault();  //prevent form from submitting
//       analytics.track('search event', {
//         value: e.value
//       })
//     });
//   });

//   // Click on Balance Card Caret
//   $('[data-selector="address-balance-caret"]').on('click', function() {
//     analytics.track('address balance caret click')
//   });

//   // Copy address
//   $('[data-selector="copy-address"]').on('click', function() {
//     analytics.track('copy address click')
//   })

//   // QR code
//   $('[data-selector="qr-code"]').on('click', function() {
//     analytics.track('QR code click')
//   })

//   // "view more transfers" click
//   $('[data-selector="token-transfer-open"]').on('click', function() {
//     analytics.track('\"View more transfers\" click')
//   })
// }