#! /usr/bin/env ruby
# -*- coding:utf-8 -*-
#require 'sinatra'
#require 'sinatra/base'
#require 'padrino-core/application/routing'
#require 'padrino-cache'

require 'sinatra'
require 'sinatra/base'
#require 'padrino-core/application/routing'
#require 'padrino-core'
#require 'padrino-cache'
require 'sinatra/reloader'

USERNAME = 'seijiro'
PASS = 'hoge'
FILEDIR = "/var/smb/sdb1/textreader"

#/Volumes/seijiro/.rvm/gems/ruby-1.9.3-p0/gems/padrino-cache-0.10.5/lib/padrino-cache/store/
module Padrino
  module Cache
    module Store
      class File
        def set(key, value, opts = nil)
          init
          if opts && opts[:expires_in]
            expires_in = opts[:expires_in].to_i
            expires_in = Time.new.to_i + expires_in if expires_in < EXPIRES_EDGE
          else
            expires_in = -1
          end
          value = Marshal.dump(value) if value
          ::File.open(path_for_key(key), 'w') { |f| f << expires_in.to_s.force_encoding('utf-8') << "\n" << value.force_encoding('utf-8') } if value
        end
        
        def get(key)
          init
          if ::File.exist?(path_for_key(key))
            puts key
            contents = ::File.read(path_for_key(key)).force_encoding('ASCII-8BIT')
            #            contents = ::File.read(path_for_key(key)).force_encoding('UTF-8')
            expires_in, body = contents.split("\n", 2)
            expires_in = expires_in.to_i
            if expires_in == -1 or Time.new.to_i < expires_in
              Marshal.load(body) if body
            else
              delete(key)
              nil
            end
          else
            nil
          end
        end
      end
    end
  end
end

def get_prefix
  ""
end

class MyApp < Sinatra::Application
  set :app_name, "textreader"

  configure :production do
    #  Sinatra::Xsendfile.replace_send_file! #replaces sinatra's send_file with x_send_file
    #    set :xsf_header, 'X-Accel-Redirect' #setting default(X-SendFile) header (nginx)
  end
end

require 'digest'
require 'kconv'
require 'json'

class MyApp < Sinatra::Application
  #  register Padrino::Routing
  #  register Padrino::Cache

  #  enable :caching

  #loggerがPadrino::loggerじゃなくなる。挙動は追いかけきれていない。
  def logger
    Padrino::logger
  end

  ### helper ##################
  require 'tilt'
  Tilt.register 'rjs', Tilt::ERBTemplate
  Tilt.register 'rcss', Tilt::ERBTemplate

  # need modify environment
  helpers do
    def title
      #    get_prefix.gsub("/","")
      :textreader
    end

    def get_prefix
      "/textreader"
    end

    def protected!
      unless authorized?
        response['WWW-Authenticate'] = %(Basic realm="filedb Restricted Area")
        throw(:halt, [401, "Not authorized\n"])
      end
    end

    def authorized?
      @auth ||=  Rack::Auth::Basic::Request.new(request.env)
      @auth.provided? && @auth.basic? && @auth.credentials && @auth.credentials == [USERNAME, PASS]
    end

    def text(path)
      
      file = path #params[:file]
      ext = File.extname(file).downcase.gsub('.','')
      isHtml = (ext == "htm" || ext == "html")
      lines = []
      reg_br = Regexp.compile("\<br\/?>",Regexp::IGNORECASE)
      reg_p = Regexp.compile("\<p\>",Regexp::IGNORECASE)
      reg_zenParen = Regexp.compile("［＃(.+?)］")
      reg_zenSpace = Regexp.compile("　")
      reg_ruby = Regexp.compile("《.+?》")
      reg_zenBar = Regexp.compile("｜")
      reg_Sasie = Regexp.compile("［＃挿絵（(img\/.+?\.jpg)）.*?］",Regexp::IGNORECASE)
      reg_IMG = Regexp.compile("src=\"(.*)?\"",Regexp::IGNORECASE)
      # 26 ： ◆lBfim5lafk ：2015/05/16(土) 02:09:56.22
      reg_2ch = Regexp.compile("^[0-9].*[0-9]$")
      File.open(file,"r:sjis") do |io|
        io.each do |line|
          line = line.toutf8
          if isHtml
            if line =~ /<title>(.*)<\/title>/i
              line = "<h2>#{$1}</h2><br/>"
            end
            line = "" if line =~ /^<!DOCTYPE/i
            line = "" if line =~ /^<html\/?>/i
            line = "" if line =~ /^<head\/?>/i
            line = "" if line =~ /^<br\/?>/i
            line = "" if line =~ /^<body>/i
            line = "" if line =~ /<style/i
            line = "" if line =~ /<div/i
            line = "" if line =~ /戻る/i
          else
            if line =~ reg_Sasie
              begin
                buff = [File.open("#{File.dirname(file)}/#{$1}","rb").read].pack('m')
                line = "<img src='data:image/jpeg;base64,#{buff}'><br>"
              rescue => ex
                line = "[挿絵]"
              end
            elsif line =~ reg_IMG
              begin
                buff = [File.open("#{File.dirname(file)}/#{$1}","rb").read].pack('m')
                line = "<img src='data:image/jpeg;base64,#{buff}'><br>"
              rescue => ex
                line = "[挿絵]"
              end
            else
              line = line.chomp
              if line =~ reg_2ch
                line = "<p style='color:gray'>#{line}</p>"
              else
                line = "<p>#{line}</p>"  
              end
            end
          end
          lines << line
        end
      end
      if !isHtml
        lines[0] = "<h2>#{lines[0]}</h2>"
        lines[1] = "<h4 style='text-align:right;'>#{lines[1]}</h4>"
      end
      lines.join("\n")
        .gsub(reg_br,'')
        .gsub(reg_zenSpace,'')
        .gsub(/［＃小見出し］(.*)/,'<h3>\1</h3>')
        .gsub(/［＃地付き］(.*)/,'<span style="float:right;text-align:right;width:100%;">\1</span>')
        .gsub(/［＃改.*?］/,'<br/><br/><br/>')
        .gsub(/［＃.段階大きな文字］(.*)/,'<span style="line-height:1.5em;font-size:3em">\1</span></p>')
        .gsub(reg_zenParen,'')
        .gsub(reg_ruby,'')
        .gsub(reg_zenBar,'')
    end
    
  end

  ### page ####################
  get "#{get_prefix}/"  do
    protected!
    dir = FILEDIR
    @text_files =  Dir.glob("#{dir}/**/*.txt")
    @text_files += Dir.glob("#{dir}/**/*.html")
    @text_files += Dir.glob("#{dir}/**/*.htm")

    dojin = "/var/www/images/d"
    @dirs = Dir.glob("#{dojin}/*/*.jpg")
      .map{|d| d.gsub(/(\/\d+)?\.jpg/,"")}.uniq
      .map{|d| "#{get_prefix}/dojin/#{d.gsub(/\/var\/www\/images\/d\//,'')}"}
    erb :index
  end

  get "#{get_prefix}/dojin/all" do
    begin
      protected!
      dojin = "/var/www/images/d"
      @s = Dir.glob("#{dojin}/*/*.jpg").map{|u| u.gsub(/\/var\/www/,"")}.sort
      @files = @s.to_json
      erb :dojin
    rescue
      "error"
    end
  end    

  get "#{get_prefix}/dojin/:num" do
    begin
      protected!
      dojin = "/var/www/images/d"
      @s = Dir.glob("#{dojin}/#{params[:num]}/*.jpg").map{|u| u.gsub(/\/var\/www/,"")}.sort
      @files = @s.to_json
      erb :dojin
    rescue
      "error"
    end
  end    


  get "#{get_prefix}/_"  do
    protected!
    
    dir = "/var/smb/sdb1/pdf"
    @text_files = cache( "textfiles1", :expires_in => 360000000 ) do
      Dir.glob("#{dir}/**/*.txt")
    end
    @text_files += cache( "textfiles2", :expires_in => 360000000 ) do
      Dir.glob("#{dir}/**/*.html")
    end
    @text_files += cache( "textfiles3", :expires_in => 360000000 ) do
      Dir.glob("#{dir}/**/*.htm")
    end
    
    dir = "/var/smb/sdb1/txt"
    @text_files += cache( "textfiles4", :expires_in => 360000000 ) do
      Dir.glob("#{dir}/**/*.txt")
    end
    @text_files += cache( "textfiles5", :expires_in => 360000000 ) do
      Dir.glob("#{dir}/**/*.html")
    end
    @text_files += cache( "textfiles6", :expires_in => 360000000 ) do
      Dir.glob("#{dir}/**/*.htm")
    end
    @uramode = true
    erb :index
  end

  
  get "#{get_prefix}/read"  do
    protected!
    @text = text(params[:file])
    @file = File.basename params[:file]
    erb :read
  end

  get "/textreader/read" do
    protected!
    @text = text(params[:file])
    @file = File.basename params[:file]
    erb :read
  end

  get "/read" do
    protected!
    @text = text(params[:file])
    @file = File.basename params[:file]
    erb :read
  end

  get "read" do
    protected!
    @text = text(params[:file])
    @file = File.basename params[:file]
    erb :read
  end
  

  
  ##########  manage  ###########################################

  ##########  /manage  ###########################################

  ### API #####################

  ### static #############
  get "#{get_prefix}/scripts/application.js" do
    @prefix = get_prefix
    content_type 'application/javascript'  
    erb :'scripts/application' 
  end

  get "#{get_prefix}/css/pc.css" do
    @prefix = get_prefix
    content_type 'text/css'
    erb :'css/pc' 
  end

  get "scripts/application.js" do
    @prefix = get_prefix
    content_type 'application/javascript'  
    erb :'scripts/application' 
  end

  get "css/pc.css" do
    @prefix = get_prefix
    content_type 'text/css'
    erb :'css/pc' 
  end

  get "/textreader/scripts/application.js" do
    @prefix = get_prefix
    content_type 'application/javascript'  
    erb :'scripts/application' 
  end

  get "/textreader/css/pc.css" do
    @prefix = get_prefix
    content_type 'text/css'
    erb :'css/pc' 
  end

  get "/textreader/jquery.js" do |path|
    send_file File.dirname(__FILE__).to_s + "/public/jquery.js"
  end

  ### TEST #####################
end
