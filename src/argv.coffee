{apiVersion} = require '../package.json'
logger = require './logger'
yargs = require 'yargs'

argv = yargs
  .usage 'Usage: $0 [options]'
  .help 'help'
  .default
    loginurl: 'https://test.salesforce.com'
    version: apiVersion
    target: 0.76
    class: 'CoverageInflation'
    pollTimeout: 600 * 1000
    pollInterval: 5 * 1000
  .demand ['username', 'password']
  .count 'verbose'
  .alias
    l: 'loginurl'
    u: 'username'
    p: 'password'
    v: 'verbose'
  .describe
    loginurl: 'Login URL'
    username: 'Username'
    password: 'Password + Security Token'
    version: 'Package version'
    verbose: 'Sets node logging level'
    class: 'Change the default coverage class name'
    target: 'Percent coverage required (0.01-0.99)'
  .wrap yargs.terminalWidth()
  .argv

constrainTargetCoverage = (argv) ->
  if 0.01 < argv.targetCoverage < 0.99
    argv.targetCoverage = Math.max 0.01, Math.min 0.99, argv.targetCoverage
    logger.warn 'Adjusted target coverage to %d. Valid range is 0.01-0.99.', argv.targetCoverage

setLogLevel = (argv) ->
  argv.logLevel = switch argv.verbose
    when 0 then 'info'
    when 1 then 'verbose'
    when 2 then 'debug'
    when 3 then 'silly'
    else 'info'

# post-init
constrainTargetCoverage argv
setLogLevel argv

module.exports = argv
