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

handleEsaWebhook = (payload) ->
  # https://docs.esa.io/posts/37
  if payload.kind is undefined || payload.team is undefined || payload.user is undefined
    return {
      kind: null
      data: null
    }
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
  return parsed

class EsaClientRobot
  constructor: (@robot, @team, @access_token) ->

  baseUrl = ()->
    "https://api.esa.io/v1/teams/#{@team}"

  getRequest = (path, callback) ->
    @robot.http("#{baseUrl.call @}#{path}").query({access_token: @access_token}).get() (error, response, body) ->
      if response.statusCode is 200
        callback(JSON.parse(body))
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
  robot.router.post options.endpoint, (req, res) ->
    # https://docs.esa.io/posts/37#3-4-0
    unless req.headers['user-agent'] == 'esa-Hookshot/v1'
      robot.logger.warning "Requested unknown user agent: #{req.headers['user-agent']}"
      res.writeHead(403)
      res.end()
      return

    if options.webhook_secret
      # https://docs.esa.io/posts/37#3-4-4
      signature = 'sha256=' + crypto.createHmac('sha256', options.webhook_secret).update(JSON.stringify(req.body), 'utf-8').digest('hex')
      unless req.headers['x-esa-signature'] is signature
        robot.logger.warning "Requested with invalid signature: #{req.headers['x-esa-signature']} != #{signature}"
        res.writeHead(401)
        res.end()
        return

    # https://docs.esa.io/posts/37#3-4-3
    lastFlushedAt = robot.brain.get('esaWebhookLogsLastFlushedDateTime') or new Date().getTime() - 3600 * 1000 * 24 * 2
    if lastFlushedAt < (new Date().getTime() - 3600 * 1000 * 24)
      robot.brain.set 'esaWebhookDeliveries', []
      robot.brain.set 'esaWebhookLogsLastFlushedDateTime', new Date().getTime()

    deliveries = robot.brain.get('esaWebhookDeliveries') or []
    if req.headers['x-esa-delivery']
      if deliveries.indexOf(req.headers['x-esa-delivery']) > -1
        res.writeHead(204)
        res.end()
        return
      else
        deliveries.push req.headers['x-esa-delivery']
        robot.brain.set 'esaWebhookDeliveries', deliveries

    parsed = handleEsaWebhook(req.body or {})
    robot.emit 'esa.webhook', parsed.kind, parsed.data
    res.writeHead(204)
    res.end()

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

  unless options.just_emit
    prefix_tori = '(\\( ⁰⊖⁰)\/) '
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

    robot.on 'esa.hear.stats', (res, stats) ->
      res.send "Members: #{stats.members}\nPosts: #{stats.posts}\nComments: #{stats.comments}\nStars: #{stats.stars}\nDaily Active Users: #{stats.daily_active_users}\nWeekly Active Users: #{stats.weekly_active_users}\nMonthly Active Users: #{stats.monthly_active_users}"

    robot.on 'esa.hear.post', (res, post) ->
      mes = prefix_tori + "#{post.full_name}\nStars: #{post.stargazers_count}, Watchers: #{post.watchers_count}, Comments: #{post.comments_count}"
      mes += ", Tasks: #{post.done_tasks_count}/#{post.tasks_count}" if post.tasks_count > 0
      res.send  mes

    robot.on 'esa.hear.comment', (res, comment) ->
      res.send prefix_tori + "#{comment.body_md}"
