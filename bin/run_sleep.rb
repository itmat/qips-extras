#!/usr/bin/env ruby

#########################################
##
#    Andrew Brader @ UPENN
#    Simple example loops through input files and reverses them
#    then adds .rev to the end and passes relevent info back to node daemon
#    --input_files='file1,file2'
#   
#    This can be modified to fit most needs. 
#

require 'rubygems'
require 'optparse'
require 'json' 

#command to execute
CMD = 'sleep'

#holder for stdout from exec
out = ''

#list of output files
outputs = Array.new

#lets get input files from command line
options = {}

OptionParser.new do |opts|
  opts.banner = "Usage: run_sleep.rb [seconds]"
  
  options[:secs] = 0
  opts.on("-s", "--seconds SECS", "Seconds to sleep") do |secs|
    options[:secs] = secs
  end
end.parse!

#loop through each input file and run command
# redirects error to error file and then captures error

error = ''

begin
  
  ##################################################################################################
  #
  #   we do all the work in a begin / rescue block just in case there are any unforseen exceptions.  
  #   this way anything that goes wrong is caught and passed back to qips-node daemon
  #

  tstamp = Time.now.to_i
  out += "Processing #{CMD} for #{options[:secs]} secs...\n"
  out += `#{CMD} #{options[:secs]} 1> #{tstamp.to_s}.sleep 2> temp.err` #redirects to output file, and redirects error
  outputs << "#{tstamp.to_s}.sleep"
  error += "#{$?}: " + `cat temp.err` + "\n" unless $?.to_i == 0 # $? is a special var for error code of process
  # error = "FORCED ERROR" if rand(2) == 1 # uncomment to force an error half the time

rescue Exception => e

  error += "#{e.message}\n"
  error += e.backtrace.join("\n")
  error += "\n"
  
end


#now we pack everything in a hash and print it 

h = Hash.new
h["result"] = out
h["output_files"] = outputs
h["error"] = error unless error.empty?

puts h.to_json









