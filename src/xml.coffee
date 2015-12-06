fs      = require 'fs-extra'
{pd}    = require 'pretty-data'
_       = require 'lodash'
js2xml  = require 'jstoxml'
argv    = require './argv'

METADATA_XMLNS = 'http://soap.sforce.com/2006/04/metadata'

module.exports =
  writePackage: (components, path, options, done) ->
    if _.isFunction options
      done = options
      options = {}

    version = options.version ? argv.version

    data = _ components
      .mapValues (arr) -> _.sortBy arr, _.method 'toLowerCase'
      .mapValues (arr) -> _.uniq arr, true
      .keys()
      .sort()
      .map (type) ->
        members = _.map components[type], (members) -> {members}
        types: [name: type].concat members
      .thru (value) ->
        _name: 'Package'
        _attrs: xmlns: METADATA_XMLNS
        _content: [{version}].concat value
      .value()

    xml = js2xml.toXML data, header: true
    fs.outputFile path, pd.xml(xml), done

  writeMetaXml: (type, path, options, done) ->
    if _.isFunction options
      done = options
      options = {}

    apiVersion = options.version ? argv.version
    status = options.status ? 'Active'

    extra =
      switch type
        when 'ApexClass'
          [{status}]

    data =
      _name: type
      _attrs: xmlns: METADATA_XMLNS
      _content: [{apiVersion}].concat extra

    xml = js2xml.toXML data, header: true
    fs.outputFile path, pd.xml(xml), done
