#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

root = File.dirname(__FILE__)
ENV['BUNDLE_GEMFILE'] ||= File.join(root, 'Gemfile')

require 'rubygems'
require 'bundler'
Bundler.require
require 'logger'

module Yukinyamap
  module Helper
    def root
      File.dirname(File.expand_path(__FILE__))
    end

    def config
      return @config if @config

      path = File.join(root, 'config', 'config.yml')
      @config = YAML.load_file(path)
    end

    def logger
      return @logger if @logger

      path = File.join(root, 'log', 'yukinyamap.log')
      @logger = Logger.new(path)
    end

    def tee(msg, level = :info)
      if [:error, :warn, :fatal].include?(level)
        error msg
      else
        say msg
      end
      logger.send level, msg
    end

    def say(msg)
      $stdout.puts msg
    end

    def error(msg)
      if msg.is_a?(Exception)
        $stderr.puts "#{msg.message} (#{msg.class})\n" << (msg.backtrace || []).join("\n")
      else
        $stderr.puts msg
      end
    end

    def tagger
      @tagger ||= Natto::MeCab.new('-O wakati')
    end

    def db
      @db ||= Mongo::Connection.new.db('yukinyamap')
    end
  end

  class Stream
    include Helper

    def initialize
      setup
    end

    def setup
      @client = UserStream.client(config[:twitter])
      @hooks  = []
      @hooks  << MongoHook.new
      @hooks  << LogHook.new
    end

    def start
      loop do
        begin
          @client.user do |status|
            @hooks.each do |h|
              h.call(status) rescue tee $!, :warn
            end
          end
        rescue UserStream::Unauhtorized
          tee $!, :error
          raise SystemExit
        rescue
          tee $!, :error
        end
        sleep 1
      end
    end
  end

  class MongoHook
    include Helper

    def call(status)
      if status.text
        status.keywords = tagger.parse(status.text).split(' ')
      end
      col_key = %w{friends event delete}.find {|key| status.key?(key)} || 'status'
      db.collection(col_key).insert(status)
    end
  end

  class LogHook
    include Helper

    def call(status)
      say status
    end
  end
end

Yukinyamap::Stream.new.start
