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
import 'bootstrap/js/dist/dropdown'
import 'bootstrap/js/dist/tooltip'

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

import './pages/chain'
import './pages/layout'
import './pages/dark-mode-switcher'

import './lib/from_now'
import './lib/indexing'
import './lib/loading_element'
import './lib/market_history_chart'
import './lib/reload_button'
import './lib/stop_propagation'
import './lib/tooltip'
