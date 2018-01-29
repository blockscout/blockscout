exports.config = {
  // See http://brunch.io/#documentation for docs.
  files: {
    javascripts: {
      entryPoints: {
        'js/app.js': 'js/app.js',
        'js/test.js': 'js/test.js'
      }

      // To use a separate vendor.js bundle, specify two files path
      // http://brunch.io/docs/config#-files-
      // joinTo: {
      //   'js/app.js': /^js/,
      //   'js/vendor.js': /^(?!js)/
      // }
      //
      // To change the order of concatenation of files, explicitly mention here
      // order: {
      //   before: [
      //     'vendor/js/jquery-2.1.1.js',
      //     'vendor/js/bootstrap.min.js'
      //   ]
      // }
    },
    stylesheets: {
      joinTo: {
        'css/app.css': 'css/app.scss'
      }
    },
    templates: {
      joinTo: 'js/app.js'
    }
  },

  conventions: {
    // This option sets where we should place non-css and non-js assets in.
    // By default, we set this to '/assets/static'. Files in this directory
    // will be copied to `paths.public`, which is 'priv/static' by default.
    assets: /^(static)/
  },

  // Phoenix paths configuration
  paths: {
    // Dependencies and current project directories to watch
    watched: ['static', 'css', 'css/**', 'js', 'vendor'],
    // Where to compile files to
    public: '../priv/static'
  },

  // Configure your plugins
  plugins: {
    babel: {
      // Do not use ES6 compiler in vendor code
      ignore: [/vendor/]
    },

    sass: {
      mode: 'native',
      precision: 8,
      allowCache: true,
      options: {
        includePaths: ['node_modules/normalize-scss/sass']
      }
    }
  },

  modules: {
    autoRequire: {
      'js/app.js': ['js/app'],
      'js/test.js': ['js/test']
    }
  },

  npm: {
    enabled: true
  }
}
