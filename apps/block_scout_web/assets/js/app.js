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

import './pages/layout'
import './pages/dark-mode-switcher'
import './pages/stakes'

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
import './lib/ad'
