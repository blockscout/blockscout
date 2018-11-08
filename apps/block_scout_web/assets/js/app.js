// We need to import the CSS so that webpack will load it.
// The ExtractTextPlugin is used to separate it out into
// its own CSS file.
import '../css/app.scss'

// webpack automatically concatenates all files in your
// watched paths. Those paths can be configured as
// endpoints in "webpack.config.js".
//
// Import dependencies
//
import '@babel/polyfill'
import 'phoenix_html'
import 'bootstrap'

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import './locale'

import './pages/address'
import './pages/blocks'
import './pages/chain'
import './pages/pending_transactions'
import './pages/reorgs'
import './pages/transaction'
import './pages/transactions'
import './pages/uncles'

import './lib/clipboard_buttons'
import './lib/currency'
import './lib/from_now'
import './lib/indexing'
import './lib/loading_element'
import './lib/market_history_chart'
import './lib/pending_transactions_toggle'
import './lib/pretty_json'
import './lib/reload_button'
import './lib/smart_contract/read_only_functions'
import './lib/smart_contract/wei_ether_converter'
import './lib/stop_propagation'
import './lib/token_balance_dropdown'
import './lib/token_balance_dropdown_search'
import './lib/token_transfers_toggle'
import './lib/tooltip'
import './lib/try_api'
import './lib/swappable_item'
