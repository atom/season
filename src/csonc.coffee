optimist = require 'optimist'
stdin = require 'stdin'
CSON = require 'cson-safe'

module.exports = (argv=[]) ->
  options = optimist(argv)
  options.usage('Usage: csonc < input_file [> output_file]')
  options.alias('r', 'root').boolean('root').describe('root', 'Require that the input file contain an object at the root.').default('root', false)
  argv = options.argv

  stdin (data) ->
    try
      object = CSON.parse(data)

      if argv.r and (!_.isObject(object) or _.isArray(object))
        console.error("CSON data does not contain a root object")
        process.exit(1)
        return
    catch e
      console.error("Parsing data failed:", e.message)
      process.exit(1)

    console.log CSON.stringify(object)
