_      = require 'lodash'
Server = require './src/server'

class Command
  constructor: ->
    @server = new Server
      port             : process.env.PORT ? 80
      namespace        : process.env.NAMESPACE ? 'meshblu'
      jobTimeoutSeconds: parseInt(process.env.JOB_TIMEOUT_SECONDS ? 30)
      jobLogRedisUri   : process.env.JOB_LOG_REDIS_URI
      jobLogQueue      : process.env.JOB_LOG_QUEUE
      jobLogSampleRate : parseFloat(process.env.JOB_LOG_SAMPLE_RATE)
      redisUri         : process.env.REDIS_URI
      cacheRedisUri    : process.env.CACHE_REDIS_URI
      firehoseRedisUri : process.env.FIREHOSE_REDIS_URI
      maxConnections   : parseInt(process.env.CONNECTION_POOL_MAX_CONNECTIONS ? 100)
      aliasServerUri   : process.env.ALIAS_SERVER_URI

  run: =>
    @server.run (error) =>
      return @panic error if error?
      {address,port} = @server.address()
      console.log "listening on #{address}:#{port}"

    process.on 'SIGTERM', =>
      console.log 'SIGTERM received, shutting down...'
      @server.stop =>
        process.exit 0

  panic: (error) =>
    console.error error.stack
    process.exit 1

command = new Command
command.run()
