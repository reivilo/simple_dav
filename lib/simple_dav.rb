# Author:: od (mailto:od@idfuze.com)
# Copyright:: 2012 IDFUZE.COM Olivier DIRRENBERGER - Released under the terms of the MIT license
# 
# This work is a part for PLUG&WORK project http://v4.myplugandwork.com
# 
# :title:SimpleDav

require 'uri'
require 'httpclient'
require 'nokogiri'
require 'logger'

$:.unshift File.join(File.dirname(__FILE__),'..','lib')
require 'simple_dav/base'
require 'simple_dav/address_book'
require 'simple_dav/card'
