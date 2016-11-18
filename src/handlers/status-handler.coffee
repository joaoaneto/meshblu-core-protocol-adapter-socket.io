class StatusHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'GetStatus'

    @jobManager.do request, (error, response) =>
      return callback error: error.message if error?
      return callback JSON.parse response.rawData

module.exports = StatusHandler
