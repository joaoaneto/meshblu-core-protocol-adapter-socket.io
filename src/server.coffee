http = require 'http'
SocketIO = require 'socket.io'
SocketIOHandler = require './socket-io-handler'

class Server
  constructor: (options) ->
    {@client, @timeoutSeconds, @port, @meshbluConfig} = options

  address: =>
    @server.address()

  start: (callback) =>
    @server = http.createServer()
    @server.on 'request', @onRequest
    @io = SocketIO @server
    @io.on 'connection', @onConnection
    @server.listen @port, callback

  stop: (callback) =>
    @server.close callback

  onConnection: (socket) =>
    socketIOHandler = new SocketIOHandler
      socket: socket
      client: @client
      timeoutSeconds: @timeoutSeconds
      meshbluConfig: @meshbluConfig

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
