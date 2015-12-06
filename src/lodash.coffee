_ = null

adder = (customizer, acc, value, key) ->
  acc + +customizer value, key

mixins =
  sum: (collection, customizer=_.identity, thisArg) ->
    if _.isString customizer
      customizer = _.property customizer
    _.reduce collection, _.partial(adder, customizer), 0, thisArg

module.exports = (lodash) ->
  _ = lodash
  _.mixin mixins
  return
