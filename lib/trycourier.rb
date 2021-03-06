require "trycourier/events"
require "trycourier/brands"
require "trycourier/lists"
require "trycourier/profiles"
require "trycourier/session"
require "trycourier/messages"
require "trycourier/version"
require "trycourier/exceptions"
require "net/http"
require "json"
require "openssl"

module Courier
  class SendResponse
    attr_reader :code
    attr_reader :message_id

    def initialize(code, message_id)
      @code = code
      @message_id = message_id
    end
  end

  class Client
    def initialize(auth_token = nil, username: nil, password: nil, base_url: nil)
      base = if base_url
        base_url
      elsif ENV["COURIER_BASE_URL"]
        ENV["COURIER_BASE_URL"]
      else
        "https://api.courier.com"
      end

      @session = Courier::CourierAPISession.new(base)

      if auth_token
        @session.init_token_auth(auth_token)
      elsif ENV["COURIER_AUTH_TOKEN"]
        @session.init_token_auth(ENV["COURIER_AUTH_TOKEN"])
      elsif username && password
        @session.init_basic_auth(username, password)
      elsif ENV["COURIER_AUTH_USERNAME"] && ENV["COURIER_AUTH_PASSWORD"]
        @session.init_basic_auth(ENV["COURIER_AUTH_USERNAME"], ENV["COURIER_AUTH_PASSWORD"])
      end

      @messages = Courier::Messages.new(@session)
      @profiles = Courier::Profiles.new(@session)
      @lists = Courier::Lists.new(@session)
      @events = Courier::Events.new(@session)
      @brands = Courier::Brands.new(@session)
    end

    def send(body)
      if not body.is_a?(Hash)
        raise InputError, "Client#send must be passed a Hash as first argument."
      elsif body["event"] == nil && body[:event] == nil
        raise InputError, "Must specify the 'event' key in Hash supplied to Client#send."
      elsif body["recipient"] == nil && body[:recipient] == nil
        raise InputError, "Must specify the 'recipient' key in Hash supplied to Client#send."
      elsif (body["data"] != nil and not body["data"].is_a?(Hash)) || (body[:data] != nil and not body[:data].is_a?(Hash))
        raise InputError, "The 'data' key in the Hash supplied to Client#send must also be a Hash."
      elsif (body["profile"] != nil and not body["profile"].is_a?(Hash)) || (body[:profile] != nil and not body[:profile].is_a?(Hash))
        raise InputError, "The 'profile' key in the Hash supplied to Client#send must also be a Hash."
      end

      res = @session.send("/send", "POST", body: body)

      code = res.code.to_i
      obj = JSON.parse res.read_body

      if code == 200
        message_id = obj["messageId"]
        SendResponse.new(code, message_id)
      elsif (message = obj["Message"].nil? ? obj["message"] : obj["Message"])
        err = "#{code}: #{message}"
        raise CourierAPIError, err
      end
    end

    # getters for all class variables

    attr_reader :session

    attr_reader :messages

    attr_reader :profiles

    attr_reader :events

    attr_reader :lists

    attr_reader :brands
  end
end
