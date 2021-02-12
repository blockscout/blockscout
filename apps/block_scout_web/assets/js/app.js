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
import 'phoenix_html'
import 'bootstrap'

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import './locale'
/*
import './pages/address'
import './pages/address/coin_balances'
import './pages/address/transactions'
import './pages/address/logs'
import './pages/address/validations'
import './pages/address/signed'
import './pages/address/internal_transactions'
import './pages/blocks'
import './pages/chain'
import './pages/pending_transactions'
import './pages/survey_banner'
import './pages/transaction'
import './pages/transactions'
*/
import './pages/layout'
import './pages/dark-mode-switcher'
import './lib/clipboard_buttons'
import './lib/currency'
import './lib/from_now'
import './lib/indexing'
import './lib/loading_element'
import './lib/pending_transactions_toggle'
import './lib/pretty_json'
import './lib/reload_button'
import './lib/stop_propagation'
import './lib/tooltip'
import './lib/modals'
import './lib/card_tabs'
import './lib/analytics'
