{apiVersion} = require '../package.json'

argv = require 'yargs'
  .usage 'Usage: $0 [options]'
  .help 'help'
  .default
    'loginurl': 'https://test.salesforce.com'
    'logLevel': 'info'
    'version': apiVersion
    'targetCoverage': 0.75
  .demand ['u', 'p']
  .alias
    'u': 'username'
    'p': 'password'
  .describe
    'loginurl': 'Login URL'
    'u': 'Username'
    'p': 'Password + Security Token'
    'version': 'Package version'
    'logLevel': 'Sets node logging level'
    'targetCoverage': 'Percent coverage required'
  .argv

argv.targetCoverage = Math.max 0.75, Math.min argv.targetCoverage, 1.0

module.exports = argv
