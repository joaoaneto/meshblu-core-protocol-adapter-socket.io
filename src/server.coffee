_                     = require 'lodash'
http                  = require 'http'
SocketIO              = require 'socket.io'
SocketIOHandler       = require './socket-io-handler'
RedisPooledJobManager = require 'meshblu-core-redis-pooled-job-manager'
redis                 = require 'ioredis'
RedisNS               = require '@octoblu/redis-ns'
MessengerFactory      = require './messenger-factory'
UuidAliasResolver     = require 'meshblu-uuid-alias-resolver'

class Server
  constructor: (options) ->
    {@disableLogging, @port, @aliasServerUri} = options
    {@maxConnections, @redisUri, @namespace, @jobTimeoutSeconds} = options
    {@jobLogRedisUri, @jobLogQueue, @jobLogSampleRate} = options
    throw new Error('need a jobLogQueue') unless @jobLogQueue?
    throw new Error('need a jobLogSampleRate') unless @jobLogSampleRate?

  address: =>
    @server.address()

  run: (callback) =>
    @server = http.createServer()

    @jobManager = new RedisPooledJobManager {
      jobLogIndexPrefix: 'metric:meshblu-core-protocol-adapter-socket.io-v1'
      jobLogType: 'meshblu-core-protocol-adapter-socket.io-v1:request'
      minConnections: 5
      idleTimeoutMillis: 5*60*1000
      @jobTimeoutSeconds
      @jobLogQueue
      @jobLogRedisUri
      @jobLogSampleRate
      @maxConnections
      @redisUri
      @namespace
    }

    uuidAliasClient = _.bindAll new RedisNS 'uuid-alias', redis.createClient(@redisUri)
    uuidAliasResolver = new UuidAliasResolver
      cache: uuidAliasClient
      aliasServerUri: @aliasServerUri

    @messengerFactory = new MessengerFactory {uuidAliasResolver, @redisUri, @namespace}

    @server.on 'request', @onRequest
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  onConnection: (socket) =>
    socketIOHandler = new SocketIOHandler {socket, @jobManager, @messengerFactory}
    socketIOHandler.initialize()

  onRequest: (request, response) =>
    if request.url == '/healthcheck'
      response.writeHead 200
      response.write JSON.stringify online: true
      response.end()
      return

    response.writeHead 404
    response.end()

module.exports = Server
