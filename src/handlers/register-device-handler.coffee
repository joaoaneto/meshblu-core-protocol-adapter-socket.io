class RegisterDeviceHandler
  constructor: ({@jobManager,@auth,@requestQueue,@responseQueue}) ->

  do: (data={}, callback=->) =>
    data.discoverWhitelist ?= []
    data.discoverWhitelist.push data.owner if data.owner?
    data.configureWhitelist ?= []
    data.configureWhitelist.push data.owner if data.owner?
    data.discoverWhitelist ?= ['*']
    data.configureWhitelist ?= ['*']
    data.sendWhitelist ?= ['*']
    data.receiveWhitelist ?= ['*']

    request =
      metadata:
        jobType: 'RegisterDevice'
      data: data

    @jobManager.do @requestQueue, @responseQueue, request, (error, response) =>
      return callback error: error.message if error?
      return callback JSON.parse response.rawData

module.exports = RegisterDeviceHandler
