# frozen_string_literal: true

require 'omniauth-twitter'
require 'omniauth-facebook'
require 'omniauth-github'
require 'omniauth-google-oauth2'
require 'omniauth-amazon'
require 'deface'
require 'coffee_script'
require 'spree/core'

module SolidusSocial
  USER_DECORATOR_PATH = File.expand_path(
    "#{__dir__}/../../app/decorators/models/solidus_social/spree/user_decorator.rb"
  )

  class Engine < Rails::Engine
    include SolidusSupport::EngineExtensions::Decorators

    isolate_namespace Spree

    engine_name 'solidus_social'

    # use rspec for tests
    config.generators do |g|
      g.test_framework :rspec
    end

    initializer 'solidus_social.environment', before: 'spree.environment' do
      ::Spree::SocialConfig = ::Spree::SocialConfiguration.new
    end

    initializer 'solidus_social.decorate_spree_user' do |app|
      next unless app.respond_to?(:reloader)

      app.reloader.after_class_unload do
        # Reload and decorate the spree user class immediately after it is
        # unloaded so that it is available to devise when loading routes
        load USER_DECORATOR_PATH
      end
    end
  end

  def self.configured_providers
    ::Spree::SocialConfig.providers.keys.map(&:to_s)
  end

  def self.init_providers
    ::Spree::SocialConfig.providers.each do |provider, credentials|
      setup_key_for(provider, credentials[:api_key], credentials[:api_secret])
    end
  end

  def self.setup_key_for(provider, key, secret)
    Devise.setup do |config|
      config.omniauth provider, key, secret, setup: true
    end
  end
end

module OmniAuth
  module Strategies
    class Facebook < OAuth2
      MOBILE_USER_AGENTS =  'palm|blackberry|nokia|phone|midp|mobi|symbian|chtml|ericsson|minimo|' \
                            'audiovox|motorola|samsung|telit|upg1|windows ce|ucweb|astel|plucker|' \
                            'x320|x240|j2me|sgh|portable|sprint|docomo|kddi|softbank|android|mmp|' \
                            'pdxgw|netfront|xiino|vodafone|portalmmm|sagem|mot-|sie-|ipod|up\\.b|' \
                            'webos|amoi|novarra|cdm|alcatel|pocket|ipad|iphone|mobileexplorer|' \
                            'mobile'
      def request_phase
        options[:scope] ||= 'email'
        options[:info_fields] ||= 'email'
        options[:display] = mobile_request? ? 'touch' : 'page'
        super
      end

      def mobile_request?
        ua = Rack::Request.new(@env).user_agent.to_s
        ua.downcase =~ Regexp.new(MOBILE_USER_AGENTS)
      end
    end
  end
end
