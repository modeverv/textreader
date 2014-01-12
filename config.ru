# -*- coding:utf-8 -*-
require 'rubygems'
#require 'sinatra'
require 'sinatra/base'
require 'padrino-core/application/routing'
require 'padrino-cache'

#require '/home/seijiro/sinatra/mediadb/main.rb'
require File.dirname(__FILE__)+'/main.rb'

#use Rack::ETag
use Rack::Deflater

#run Sinatra::Application
run MyApp
