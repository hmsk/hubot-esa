Helper = require 'hubot-test-helper'
chai = require 'chai'
fs = require 'fs'

expect = chai.expect

helper = new Helper '../src/esa-slack.coffee'

describe 'esa-slack', ->
  room = null
  emitted = false
  emitted_data = null
  response = null

  initializeRoom = ->
    room = helper.createRoom()
    emitted = false
    emitted_data = null
    room.robot.on 'slack.attachment', (att) ->
      emitted = true
      emitted_data = att
    # Build response object manually
    response = null
    room.robot.respond 'esa mock response object', (res) -> response = res
    room.user.say 'gingy', '@hubot esa mock response object'

  beforeEach ->
    process.env.HUBOT_ESA_ACCESS_TOKEN = 'dummy'
    process.env.HUBOT_ESA_TEAM = 'ginger'
    process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM = 'general'
    process.env.HUBOT_ESA_WEBHOOK_ENDPOINT = '/hubot/ginger'
    process.env.HUBOT_ESA_WEBHOOK_SECRET_TOKEN = 'purrs'
    process.env.HUBOT_ESA_JUST_EMIT = 'true'

  context 'disabled by env value', ->
    beforeEach ->
      process.env.HUBOT_ESA_SLACK_DECORATOR = 'false'
      initializeRoom()

    afterEach ->
      room.destroy()

    context 'emit esa.hear.stats event', ->
      beforeEach (done)->
        @stats = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/stats.json")
        room.robot.emit 'esa.hear.stats', response, @stats
        setTimeout done, 200

      it 'not emit slack.attachment event', ->
        expect(emitted).to.equal false

  context 'enabled by env value', ->
    beforeEach ->
      process.env.HUBOT_ESA_SLACK_DECORATOR = 'true'
      initializeRoom()

    afterEach ->
      room.destroy()

    context 'emit esa.hear.stats event', ->
      beforeEach (done)->
        @stats = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/stats.json")
        room.robot.emit 'esa.hear.stats', response, @stats
        setTimeout done, 200

      it 'emit slack.attachment with base information', ->
        expect(emitted).to.equal true
        content = emitted_data.content
        expect(content.color).to.equal '#13958D'
        expect(content.thumb_url).to.equal 'https://img.esa.io/uploads/production/pictures/105/6161/image/425c3b1e777d356c34973e818543420e.gif'

      it 'emit slack.attachment with stats', ->
        content = emitted_data.content
        expect(content.pretext).to.equal 'The stats of esa'
        expect(content.fields).to.include {
          title: 'Daily Active Users'
          value: @stats.daily_active_users
          short: true
        }

    context 'emit esa.hear.post event', ->
      beforeEach (done)->
        @post = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/post.json")
        room.robot.emit 'esa.hear.post', response, @post
        setTimeout done, 200

      it 'emit slack.attachment with post', ->
        expect(emitted).to.equal true
        content = emitted_data.content
        expect(content.pretext).to.equal ''
        expect(content.title).to.equal @post.full_name
        expect(content.title_link).to.equal @post.url
        expect(content.text).to.equal @post.body_md

    context 'emit esa.hear.comment event', ->
      beforeEach (done)->
        @comment = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/comment.json")
        @post = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/post.json")
        room.robot.emit 'esa.hear.comment', response, @comment, @post
        setTimeout done, 200

      it 'emit slack.attachment with post', ->
        expect(emitted).to.equal true
        content = emitted_data.content
        expect(content.pretext).to.equal ''
        expect(content.title).to.equal ('Comment for ' + @post.full_name)
        expect(content.title_link).to.equal @comment.url
        expect(content.text).to.equal @comment.body_md
        expect(content.author_name).to.equal @comment.created_by.screen_name
        expect(content.author_icon).to.equal @comment.created_by.icon

    context 'emit esa.webhook event', ->
      buildWebhookArgs = (fixture) ->
        webhook = JSON.parse(fs.readFileSync "#{__dirname}/fixtures/webhook_#{fixture}.json")
        data =
          team: webhook.team
          user: webhook.user
          post: webhook.post
          comment: webhook.comment || null
        return [webhook.kind, data]

      expectCommonFields = (emitted, actual) ->
        expect(emitted.author_name).to.equal actual.user.screen_name
        expect(emitted.author_icon).to.equal actual.user.icon.url
        expect(emitted.title).to.equal actual.post.name
        expect(emitted.title_link).to.equal actual.post.url

      it 'emit slack.attachment for post_create', ->
        [kind, data] = buildWebhookArgs('post_create')
        room.robot.emit 'esa.webhook', kind, data
        content = emitted_data.content
        expectCommonFields(content, data)
        expect(content.pretext).to.equal 'New post created'
        expect(content.text).to.equal data.post.message

        expect(emitted_data.channel).to.equal process.env.HUBOT_ESA_WEBHOOK_DEFAULT_ROOM

      it 'emit slack.attachment for post_update', ->
        [kind, data] = buildWebhookArgs('post_update')
        room.robot.emit 'esa.webhook', kind, data
        content = emitted_data.content
        expectCommonFields(content, data)
        expect(content.pretext).to.equal 'The post updated'
        expect(content.text).to.equal data.post.message

      it 'emit slack.attachment for post_archive', ->
        [kind, data] = buildWebhookArgs('post_archive')
        room.robot.emit 'esa.webhook', kind, data
        content = emitted_data.content
        expectCommonFields(content, data)
        expect(content.pretext).to.equal 'The post archived'
        expect(content.text).to.be.undefined

      it 'emit slack.attachment for comment_create', ->
        [kind, data] = buildWebhookArgs('comment_create')
        room.robot.emit 'esa.webhook', kind, data
        content = emitted_data.content
        expectCommonFields(content, data)
        expect(content.pretext).to.equal 'The comment posted'
        expect(content.text).to.equal data.comment.body_md

      it 'emit slack.attachment for member_join', ->
        [kind, data] = buildWebhookArgs('member_join')
        room.robot.emit 'esa.webhook', kind, data
        content = emitted_data.content
        expect(content.pretext).to.equal 'New member joined'
        expect(content.text).to.equal data.user.screen_name
