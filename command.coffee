redis   = require 'redis'
RedisNS = require '@octoblu/redis-ns'
Server  = require './src/server'
MeshbluConfig = require 'meshblu-config'

class Command
  constructor: ->
    port = process.env.PORT ? 80
    namespace = process.env.NAMESPACE ? 'meshblu'
    redisUri  = process.env.REDIS_URI
    meshbluConfig = new MeshbluConfig().toJSON()

    client = new RedisNS namespace, redis.createClient(redisUri)
    @server = new Server port: port, client: client, meshbluConfig: meshbluConfig, timeoutSeconds: 30

  run: =>
    @server.start (error) =>
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
