# Descriptipn
#   Hubot script handle webhook and API of https://esa.io
#
# Dependencies:
#   None
#
# Commands:
#    hubot esa stats - Retrieve stats of your team on esa
#
# Configuration:
#   HUBOT_ESA_ACCESS_TOKEN
#   HUBOT_ESA_TEAM
#   HUBOT_ESA_WEBHOOK_DEFAULT_ROOM
#   HUBOT_ESA_WEBHOOK_ENDPOINT
#   HUBOT_ESA_WEBHOOK_SECRET_TOKEN
#   HUBOT_ESA_JUST_EMIT
#
# Author:
#   hmsk <k.hamasaki@gmail.com>
#

crypto = require 'crypto'

class EsaWebhook
  deliveriesKey = 'esaWebhookDeliveries'
  flushedDateTimeKey = 'esaWebhookLogsLastFlushedDateTime'

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

  screen = (duplicated, next) ->
    # https://docs.esa.io/posts/37#3-4-3
    lastFlushedAt = @kvs.get(flushedDateTimeKey) or new Date().getTime() - 3600 * 1000 * 24 * 2
    if lastFlushedAt < (new Date().getTime() - 3600 * 1000 * 24)
      @kvs.set deliveriesKey, []
      @kvs.set flushedDateTimeKey, new Date().getTime()

    deliveries = @kvs.get(deliveriesKey) or []
    delivered = @request.headers['x-esa-delivery']
    if delivered
      if deliveries.indexOf(delivered) > -1
        return duplicated "Already received: #{delivered}"
      else
        deliveries.push delivered
        @kvs.set deliveriesKey, deliveries
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
      screen.call @, (err) =>
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

  return robot.logger.error "Missing configuration: HUBOT_ESA_TEAM" unless options.team?
  return robot.logger.error "Missing configuration: HUBOT_ESA_ACCESS_TOKEN" unless options.token?
  return robot.logger.error "Missing configuration: HUBOT_ESA_WEBHOOK_DEFAULT_ROOM" unless options.room?

  esa = new EsaClientRobot(robot, options.team, options.token)

  robot.respond /esa stats/, (res) ->
    esa.getStats (stats) ->
      robot.emit 'esa.hear.stats', res, stats

  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)(?!(\#comment-\d+))\b/, (res) ->
    unless res.match[1] == options.team then return
    esa.getPost res.match[2], (post) ->
      robot.emit 'esa.hear.post', res, post

  robot.hear /https:\/\/(.+)\.esa\.io\/posts\/(\d+)\#comment-(\d+)\b/, (res) ->
    unless res.match[1] == options.team then return
    esa.getComment res.match[3], (comment) ->
      robot.emit 'esa.hear.comment', res, comment

  robot.router.post options.endpoint, (req, res) ->
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
      robot.emit 'esa.webhook', kind, data
      res.writeHead(204)
      res.end()

  unless options.just_emit
    prefix_tori = '(\\( ⁰⊖⁰)\/) '

    robot.on 'esa.hear.stats', (res, stats) ->
      res.send "Members: #{stats.members}\nPosts: #{stats.posts}\nComments: #{stats.comments}\nStars: #{stats.stars}\nDaily Active Users: #{stats.daily_active_users}\nWeekly Active Users: #{stats.weekly_active_users}\nMonthly Active Users: #{stats.monthly_active_users}"

    robot.on 'esa.hear.post', (res, post) ->
      mes = prefix_tori + "#{post.full_name}\nStars: #{post.stargazers_count}, Watchers: #{post.watchers_count}, Comments: #{post.comments_count}"
      mes += ", Tasks: #{post.done_tasks_count}/#{post.tasks_count}" if post.tasks_count > 0
      res.send  mes

    robot.on 'esa.hear.comment', (res, comment) ->
      res.send prefix_tori + "#{comment.body_md}"

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
