_ = require 'lodash'
winston = require 'winston'
argv = require './argv'

winston.emitErrs = true
winston.cli()

logger = new winston.Logger
  transports: [
    new winston.transports.Console
      level: argv.logLevel
      handleExceptions: true
      json: false
      prettyPrint: true
      colorize: true
      timestamp: false
  ]
  exitOnError: true

logger.cli()
logger.setLevels error: 0, warn: 1, info: 2, verbose: 3, debug: 4, silly: 5

logger.log = _.wrap logger.log, (fn, args...) ->
  [level] = args
  unless logger.levels[level]?
    args.unshift 'info'
  fn.apply logger, args

logger.stream =
  write: (message, encoding) ->
    logger.info message

module.exports = logger
