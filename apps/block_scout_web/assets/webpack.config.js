const path = require('path');
const ExtractTextPlugin = require('extract-text-webpack-plugin');
const CopyWebpackPlugin = require('copy-webpack-plugin');
const glob = require("glob");

function transpileViewScript(file) {
  return {
    devtool: 'none',
    mode: 'production',
    entry: file,
    output: {
      filename: file.replace('./js/view_specific/', ''),
      path: path.resolve(__dirname, '../priv/static/js')
    },
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader'
          }
        },
      ]
    }
  }
};

const appJs =
  {
    devtool: 'none',
    mode: 'production',
    entry: './js/app.js',
    output: {
      filename: 'app.js',
      path: path.resolve(__dirname, '../priv/static/js')
    },
    module: {
      rules: [
        {
          test: /\.js$/,
          exclude: /node_modules/,
          use: {
            loader: 'babel-loader'
          }
        },
        {
          test: /\.scss$/,
          use: ExtractTextPlugin.extract({
            use: [{
              loader: "css-loader"
            }, {
              loader: "postcss-loader"
            }, {
              loader: "sass-loader",
              options: {
                precision: 8,
                includePaths: [
                  'node_modules/bootstrap/scss',
                  'node_modules/@fortawesome/fontawesome-free/scss'
                ]
              }
            }],
            fallback: 'style-loader'
          })
        }, {
          test: /\.(svg|ttf|eot|woff|woff2)$/,
          use: {
            loader: 'file-loader',
            options: {
              name: '[name].[ext]',
              outputPath: '../fonts/',
              publicPath: '../fonts/'
            }
          }
        }
      ]
    },
    plugins: [
      new ExtractTextPlugin('../css/app.css'),
      new CopyWebpackPlugin([{ from: 'static/', to: '../' }])
    ]
  }

const viewScripts = glob.sync('./js/view_specific/**/*.js').map(transpileViewScript);

module.exports = viewScripts.concat(appJs);
