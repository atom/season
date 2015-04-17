crypto = require 'crypto'
path = require 'path'

fs = require 'fs-plus'
CSON = null # defer until used

csonCache = null

stats =
  hits: 0
  misses: 0

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
    CSON ?= require 'cson-parser'
    try
      parsed = CSON.parse(contents)
      stats.misses++
      return parsed
    catch error
      if isAllCommentsAndWhitespace(contents)
        return null
      else
        throw error
  else
    JSON.parse(contents)

parseCacheContents = (contents) ->
  parsed = JSON.parse(contents)
  stats.hits++
  parsed

parseContentsSync = (objectPath, cachePath, contents) ->
  object = parseObject(objectPath, contents)
  writeCacheFileSync(cachePath, object) if cachePath
  object

isAllCommentsAndWhitespace = (contents) ->
  lines = contents.split('\n')
  while lines.length > 0
    line = lines[0].trim()
    if line.length is 0 or line[0] is '#'
      lines.shift()
    else
      return false
  true

parseContents = (objectPath, cachePath, contents, callback) ->
  try
    object = parseObject(objectPath, contents)
  catch parseError
    parseError.path = objectPath
    parseError.message = "#{objectPath}: #{parseError.message}"
    callback?(parseError)
    return

  writeCacheFile(cachePath, object) if cachePath
  callback?(null, object)
  return

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
          return parseCacheContents(fs.readFileSync(cachePath, 'utf8'))

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
                parsed = parseCacheContents(cached)
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
    CSON ?= require 'cson-parser'
    CSON.stringify(object, visitor, space)

  getCacheHits: -> stats.hits

  getCacheMisses: -> stats.misses

  resetCacheStats: ->
    stats =
      hits: 0
      misses: 0
