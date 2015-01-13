crypto = require 'crypto'
path = require 'path'

_ = require 'underscore-plus'
fs = require 'fs-plus'
CSON = require 'cson-safe'

csonCache = null

getCachePath = (cson) ->
  digest = crypto.createHash('sha1').update(cson, 'utf8').digest('hex')
  path.join(csonCache, "#{digest}.json")

writeCacheFileSync = (cachePath, object) ->
  try
    fs.writeFileSync(cachePath, JSON.stringify(object))

writeCacheFile = (cachePath, object) ->
  fs.writeFile cachePath, JSON.stringify(object), ->

parseObject = (objectPath, contents) ->
  if path.extname(objectPath) is '.cson'
    CSON.parse(contents)
  else
    JSON.parse(contents)

parseContentsSync = (objectPath, cachePath, contents) ->
  object = parseObject(objectPath, contents)
  writeCacheFileSync(cachePath, object) if cachePath
  object

parseContents = (objectPath, cachePath, contents, callback) ->
  try
    object = parseObject(objectPath, contents)
    writeCacheFile(cachePath, object) if cachePath
    callback?(null, object)
  catch parseError
    callback?(parseError)

module.exports =
  setCacheDir: (cacheDirectory) -> csonCache = cacheDirectory

  isObjectPath: (objectPath) ->
    return false unless objectPath

    extension = path.extname(objectPath)
    extension is '.cson' or extension is '.json'

  resolve: (objectPath='') ->
    return null unless objectPath

    return objectPath if @isObjectPath(objectPath) and fs.isFileSync(objectPath)

    jsonPath = "#{objectPath}.json"
    return jsonPath if fs.isFileSync(jsonPath)

    csonPath = "#{objectPath}.cson"
    return csonPath if fs.isFileSync(csonPath)

    null

  readFileSync: (objectPath) ->
    contents = fs.readFileSync(objectPath, 'utf8')
    return null if contents.trim().length is 0
    if csonCache and path.extname(objectPath) is '.cson'
      cachePath = getCachePath(contents)
      if fs.isFileSync(cachePath)
        try
          return JSON.parse(fs.readFileSync(cachePath, 'utf8'))

    parseContentsSync(objectPath, cachePath, contents)

  readFile: (objectPath, callback) ->
    fs.readFile objectPath, 'utf8', (error, contents) =>
      return callback?(error) if error?
      return callback?(null, null) if contents.trim().length is 0

      if csonCache and path.extname(objectPath) is '.cson'
        cachePath = getCachePath(contents)
        fs.stat cachePath, (error, stat) ->
          if stat?.isFile()
            fs.readFile cachePath, 'utf8', (error, cached) ->
              try
                parsed = JSON.parse(cached)
              catch error
                try
                  parseContents(objectPath, cachePath, contents, callback)
                return
              callback?(null, parsed)
          else
            parseContents(objectPath, cachePath, contents, callback)
      else
        parseContents(objectPath, null, contents, callback)

  writeFile: (objectPath, object, callback) ->
    callback ?= ->

    try
      contents = @stringifyPath(objectPath, object)
    catch error
      callback(error)
      return

    fs.writeFile(objectPath, "#{contents}\n", callback)

  writeFileSync: (objectPath, object) ->
    fs.writeFileSync(objectPath, "#{@stringifyPath(objectPath, object)}\n")

  stringifyPath: (objectPath, object, visitor, space) ->
    if path.extname(objectPath) is '.cson'
      @stringify(object, visitor, space)
    else
      JSON.stringify(object, undefined, 2)

  stringify: (object, visitor, space = 2) ->
    CSON.stringify(object, visitor, space)
