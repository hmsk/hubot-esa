# Descriptipn
#  Hubot script handle webhook and API of https://esa.io
#
# Dependencies:
#  "crypto": "*"
#
# Commands:
#   hubot esa stats - Show stats of your team
#   https://[yourteam].esa.io/posts/[post_id] - Show information of post
#   https://[yourteam].esa.io/posts/[post_id]#comment-[comment_id] - Show comment
#
# Configuration:
#   HUBOT_ESA_ACCESS_TOKEN
#   HUBOT_ESA_TEAM
#   HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
#   HUBOT_ESA_WEBHOOK_ENDPOINT
#   HUBOT_ESA_WEBHOOK_SECRET_TOKEN
#   HUBOT_ESA_JUST_EMIT
#   HUBOT_ESA_DEBUG
#
# Author:
#   hmsk <k.hamasaki@gmail.com>

crypto = require 'crypto'

class EsaWebhook
  deliveriesKey = 'esaWebhookDeliveries'

  constructor: (@kvs, @request, @secret_token) ->
    @events =
      unauthorized: []
      duplicated: []
    if @secret_token
      @signature = 'sha256=' + crypto.createHmac('sha256', @secret_token).update(JSON.stringify(@request.body), 'utf-8').digest('hex')

  on: (name, callback) =>
    @events[name].push callback
    this

  authorize = (unauthorized, next) ->
    # https://docs.esa.io/posts/37#3-4-0
    unless @request.headers['user-agent'] is 'esa-Hookshot/v1'
      return unauthorized "Requested by unauthorized user agent: #{@request.headers['user-agent']}"

    if @signature
      # https://docs.esa.io/posts/37#3-4-4
      unless @request.headers['x-esa-signature'] is @signature
        return unauthorized "Requested with invalid signature: #{@request.headers['x-esa-signature']} != #{@signature}"
    next()

  filterHistory = (duplicated, next) ->
    # https://docs.esa.io/posts/37#3-4-3
    delivery = @request.headers['x-esa-delivery']
    log = @kvs.get(deliveriesKey) or {}
    log = {} if typeof log isnt 'object'

    for delivery_id, delivered_datetime of log
      delete log[delivery_id] if delivered_datetime < (new Date().getTime() - 3600 * 1000 * 24)
    return duplicated "Already received: #{delivery}" if log[delivery]?

    log[delivery] = new Date().getTime()
    @kvs.set deliveriesKey, log

    next()

  parse = (result) ->
    # https://docs.esa.io/posts/37
      payload = @request.body || {}
      if payload.kind is undefined || payload.team is undefined || payload.user is undefined
        return result null, null
      parsed =
        kind: payload.kind
        data:
          team: payload.team.name
          user: payload.user
          post: null
          comment: null

      switch parsed.kind
        when 'post_create', 'post_update', 'post_archive'
          parsed.data.post = payload.post
        when 'comment_create'
          parsed.data.post = payload.post
          parsed.data.comment = payload.comment

      result parsed.kind, parsed.data

  handle: (callback) ->
    authorize.call @, (err) =>
      for unauthorized_callback in @events.unauthorized
        unauthorized_callback err
    , =>
      filterHistory.call @, (err) =>
        for duplicated_callback in @events.duplicated
          duplicated_callback err
      , =>
        parse.call @, (kind, data) ->
          callback kind, data

class EsaClientRobot
  constructor: (@robot, @team, @access_token) ->

  baseUrl = ()->
    "https://api.esa.io/v1/teams/#{@team}"

  getRequest = (path, callback) ->
    @robot.http("#{baseUrl.call @}#{path}").query({access_token: @access_token}).get() (error, response, body) ->
      if response.statusCode is 200
        callback JSON.parse(body)
      else
        @robot.logger.warning "esa API GET request failed: #{error}"

  getTeam: (callback) ->
    getRequest.call @, "", callback

  getStats: (callback) ->
    getRequest.call @, "/stats", callback

  getPost: (post_id, callback) ->
    getRequest.call @, "/posts/#{post_id}", callback

  getComment: (comment_id, callback) ->
    getRequest.call @, "/comments/#{comment_id}", callback


module.exports = (robot) ->
  options =
    team: process.env.HUBOT_ESA_TEAM
    token: process.env.HUBOT_ESA_ACCESS_TOKEN
    room: process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
    endpoint: process.env.HUBOT_ESA_WEBHOOK_ENDPOINT || '/hubot/esa'
    just_emit: process.env.HUBOT_ESA_JUST_EMIT == 'true'
    webhook_secret: process.env.HUBOT_ESA_WEBHOOK_SECRET_TOKEN
    debug: process.env.HUBOT_ESA_DEBUG == 'true'

  return robot.logger.error "Missing configuration: HUBOT_ESA_TEAM" unless options.team?
  return robot.logger.error "Missing configuration: HUBOT_ESA_ACCESS_TOKEN" unless options.token?
  return robot.logger.error "Missing configuration: HUBOT_ESA_WEBHOOK_DEFAULT_ROOM" unless options.room?

  robot.on 'esa.debug', (message) ->
    robot.logger.info "hubot-esa: #{message}" if options.debug

  robot.emit 'esa.debug', 'Enabled script'

  esa = new EsaClientRobot(robot, options.team, options.token)

  robot.respond /esa stats/, (res) ->
    robot.emit 'esa.debug', 'heared stats command'
    esa.getStats (stats) ->
      robot.emit 'esa.hear.stats', res, stats
      robot.emit 'esa.debug', "emit esa.hear.stats with stats:\n#{stats}"

  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)(?!(\#comment-\d+))\b/, (res) ->
    robot.emit 'esa.debug', 'heared post url'
    [_, team, post_id] = res.match
    unless team == options.team then return
    esa.getPost post_id, (post) ->
      robot.emit 'esa.hear.post', res, post
      robot.emit 'esa.debug', "emit esa.hear.post with post:\n#{post}"

  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)\#comment-(\d+)\b/, (res) ->
    robot.emit 'esa.debug', 'heared comment url'
    [_, team, post_id, comment_id] = res.match
    unless team == options.team then return
    esa.getComment comment_id, (comment) ->
      esa.getPost post_id, (post) ->
        robot.emit 'esa.hear.comment', res, comment, post
        robot.emit 'esa.debug', "emit esa.hear.comment with post:\n#{post}\n comment:\n#{comment}"

  robot.router.post options.endpoint, (req, res) ->
    robot.emit 'esa.debug', "received a webhook by #{req.headers['user-agent']}"
    new EsaWebhook(robot.brain, req, options.webhook_secret)
    .on 'unauthorized', (err) ->
      robot.logger.warning err
      res.writeHead(401)
      res.end()
    .on 'duplicated', (err) ->
      robot.logger.warning err
      res.writeHead(409)
      res.end()
    .handle (kind, data) ->
      robot.emit 'esa.debug', "emit esa.webhook with kind: #{kind}\n data:\n#{data}"
      robot.emit 'esa.webhook', kind, data
      res.writeHead(204)
      res.end()

  unless options.just_emit
    prefix_tori = '(\\( ⁰⊖⁰)\/) '

    robot.on 'esa.hear.stats', (res, stats) ->
      res.send "Members: #{stats.members}\nPosts: #{stats.posts}\nComments: #{stats.comments}\nStars: #{stats.stars}\nDaily Active Users: #{stats.daily_active_users}\nWeekly Active Users: #{stats.weekly_active_users}\nMonthly Active Users: #{stats.monthly_active_users}"

    robot.on 'esa.hear.post', (res, post) ->
      mes = prefix_tori + "Post: #{post.full_name}\nStars: #{post.stargazers_count}, Watchers: #{post.watchers_count}, Comments: #{post.comments_count}"
      mes += ", Tasks: #{post.done_tasks_count}/#{post.tasks_count}" if post.tasks_count > 0
      res.send  mes

    robot.on 'esa.hear.comment', (res, comment, post) ->
      res.send prefix_tori + "Comment for #{post.full_name}\n#{comment.body_md}"

    robot.on 'esa.webhook', (kind, data) ->
      robot.messageRoom options.room, prefix_tori + switch kind
        when 'post_create'
           "#{data.user.screen_name} created a new post: #{if data.post.wip then '(WIP) ' else ''}#{data.post.name}\n>#{data.post.message}\n#{data.post.url}"
        when 'post_update'
           "#{data.user.screen_name} updated the post: #{if data.post.wip then '(WIP) ' else ''}#{data.post.name}\n>#{data.post.message}\n#{data.post.url}"
        when 'post_archive'
           "#{data.user.screen_name} archived the post: #{data.post.name}\n#{data.post.url}"
        when 'comment_create'
           "#{data.user.screen_name} posted a comment to #{data.post.name}\n>#{data.comment.body_md.replace("\n",'')}\n#{data.post.url}"
        when 'member_join'
           "New member joined: #{data.user.name}(#{data.user.screen_name})"
        else
          robot.logger.warning "Unknown kind of Webhook received: #{kind}"
          "Unknown kind of Webhook received #{kind}"
