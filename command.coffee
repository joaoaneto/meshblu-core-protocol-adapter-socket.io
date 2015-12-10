_             = require 'lodash'
redis         = require 'redis'
{Pool}        = require 'generic-pool'
RedisNS       = require '@octoblu/redis-ns'
Server        = require './src/server'
MeshbluConfig = require 'meshblu-config'

class Command
  constructor: ->
    port = process.env.PORT ? 80
    namespace = process.env.NAMESPACE ? 'meshblu'
    redisMaxConnections = process.env.REDIS_MAX_CONNECTIONS ? 100
    redisMaxConnections = parseInt redisMaxConnections
    timeoutSeconds = process.env.JOB_TIMEOUT_SECONDS ? 30
    timeoutSeconds = parseInt timeoutSeconds
    redisUri  = process.env.REDIS_URI
    meshbluConfig = new MeshbluConfig().toJSON()
    pool = @buildPool {namespace, redisUri, redisMaxConnections}

    @server = new Server {port, pool, meshbluConfig, timeoutSeconds}

  run: =>
    @server.start (error) =>
      return @panic error if error?
      {address,port} = @server.address()
      console.log "listening on #{address}:#{port}"
    process.on 'SIGTERM', =>
      console.log 'SIGTERM received, shutting down...'
      @server.stop =>
        process.exit 0

  buildPool: ({namespace, redisUri, redisMaxConnections}) =>
    pool = new Pool
      max: redisMaxConnections
      min: 0
      create: (callback) =>
        client = _.bindAll new RedisNS namespace, redis.createClient(redisUri)
        callback null, client
      destroy: (client) =>
        client.end true

  panic: (error) =>
    console.error error.stack
    process.exit 1

command = new Command
command.run()
