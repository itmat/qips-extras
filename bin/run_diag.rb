#!/usr/bin/env ruby

#########################################
##
#    Andrew Brader @ UPENN
#    Simple example loops through input files and appends a phrase
#    then adds .app to the end and passes relevent info back to node daemon
#    --input_files='file1,file2'  --phrase='Is it Friday yet?'
#   
#    This can be modified to fit most needs. 
#

require 'rubygems'
require 'optparse'
require 'json' 

#command to execute - Prints out Instance ID, AMI ID, Reservation ID
CMD = '/usr/local/bin/ec2-metadata -a -e -i -p -v -h -o'

#default_phrase = 'Is is Friday yet?'

#holder for stdout from exec
out = ''

#list of output files
outputs = Array.new

#lets get input files from command line
#options = {}

=begin
OptionParser.new do |opts|
  opts.banner = "Usage: run_append.rb [options]"
  
  opts.on("--input_files=MANDATORY", "--input_fies MANDATORY", "Input Files") do |v|
    options[:input_files] = v
  end
  
  opts.on("--phrase=MANDATORY", "--phrase MANDATORY", "Phrase") do |v|
    options[:phrase] = v
  end
  
end.parse!
=end

#loop through each input file and run command
# redirects error to error file and then captures error

error = ''

begin
  
  ##################################################################################################
  #
  #   we do all the work in a begin / rescue block just in case there are any unforseen exceptions.  
  #   this way anything that goes wrong is caught and passed back to qips-node daemon
  #

  #phrase = options[:phrase] ||= default_phrase

  #options[:input_files].split(',').each do |f|
    #each basename
    
    unique_id = Time.now.to_i.to_s
    filename = "ec2_diag-" + unique_id + ".out"
    out += "Processing #{CMD}...\n"
    out += `#{CMD} >> #{filename}`
    outputs << "#{filename}"
    error += "error code: #{$?} \n" unless $?.to_i == 0 # $? is a special var for error code of process
    # error = "FORCED ERROR" if rand(2) == 1 # uncomment to force an error half the time

  #end

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









