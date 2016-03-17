http = require 'http'
SocketIO = require 'socket.io'
SocketIOHandler = require './socket-io-handler'
JobLogger = require 'job-logger'
PooledJobManager = require 'meshblu-core-pooled-job-manager'
{Pool} = require 'generic-pool'
redis   = require 'redis'
RedisNS = require '@octoblu/redis-ns'

class Server
  constructor: (options) ->
    {@disableLogging, @port, @meshbluConfig} = options
    {@connectionPoolMaxConnections, @redisUri, @namespace, @jobTimeoutSeconds} = options
    {@jobLogRedisUri, @jobLogQueue} = options
    throw new Error('need a jobLogQueue') unless @jobLogQueue?

  address: =>
    @server.address()

  run: (callback) =>
    @server = http.createServer()
    connectionPool = @_createConnectionPool()

    jobLogger = new JobLogger
      indexPrefix: 'metric:meshblu-server-socket.io-v1'
      type: 'meshblu-server-socket.io-v1:request'
      client: redis.createClient(@jobLogRedisUri)
      jobLogQueue: @jobLogQueue

    @jobManager = new PooledJobManager
      timeoutSeconds: @jobTimeoutSeconds
      pool: connectionPool
      jobLogger: jobLogger

    @server.on 'request', @onRequest
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  onConnection: (socket) =>
    socketIOHandler = new SocketIOHandler {socket, @jobManager, @meshbluConfig}
    socketIOHandler.initialize()

  onRequest: (request, response) =>
    if request.url == '/healthcheck'
      response.writeHead 200
      response.write JSON.stringify online: true
      response.end()
      return

    response.writeHead 404
    response.end()

  _createConnectionPool: =>
    connectionPool = new Pool
      max: @connectionPoolMaxConnections
      min: 0
      returnToHead: true # sets connection pool to stack instead of queue behavior
      create: (callback) =>
        client = new RedisNS @namespace, redis.createClient(@redisUri)

        client.on 'end', ->
          client.hasError = new Error 'ended'

        client.on 'error', (error) ->
          client.hasError = error
          callback error if callback?

        client.once 'ready', ->
          callback null, client
          callback = null

      destroy: (client) => client.end true
      validate: (client) => !client.hasError?

    return connectionPool

module.exports = Server
