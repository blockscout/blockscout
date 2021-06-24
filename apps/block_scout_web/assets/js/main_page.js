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

import './lib/from_now'
import './lib/indexing'
import './lib/loading_element'
import './lib/tooltip'
