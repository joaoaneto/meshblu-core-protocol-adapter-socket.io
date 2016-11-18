class SendMessageHandler
  constructor: ({@jobManager,@auth}) ->

  do: (data, callback=->) =>
    request =
      metadata:
        jobType: 'SendMessage'
        auth: @auth
      data: data

    @jobManager.do request, (error, response) =>
      return callback null if error?
      return callback null unless response?
      callback null

module.exports = SendMessageHandler
