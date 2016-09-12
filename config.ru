require 'rubygems'
require 'bundler'

Bundler.require

require_relative 'postbot'
run Sinatra::Application
