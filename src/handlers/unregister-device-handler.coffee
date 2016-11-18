http = require 'http'

class UnregisterDeviceHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data={}, callback=->) =>
    {uuid} = data
    request =
      metadata:
        jobType: 'UnregisterDevice'
        auth: @auth
        toUuid: uuid
      data: {}
    @jobManager.do request, (error, response) =>
      return callback error: error.message if error?
      return callback error: http.STATUS_CODES[response.metadata.code] unless response.metadata.code == 204
      return callback {uuid}

module.exports = UnregisterDeviceHandler
