_ = require 'lodash'

# Extends JSON.stringify for circular references
JSON.stringifyCircular = (obj, indent) ->
  cache = []
  JSON.stringify obj, (key, value) ->
    return if !!~cache.indexOf value
    cache.push value if _.isObject value
    value
  , indent
