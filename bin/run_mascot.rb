#!/opt/local/bin/ruby

#########################################
##
#    David Austin @ UPENN
#    runs mascot search for given input file(s)
#    accepts mzML, mzXML, or mgf files
#    --input_files='file1,file2'
#    --taxonomy=human
#

require 'rubygems'
require 'optparse'
require 'json'
require 'restclient'
require 'curb'

#mgf command to execute if necessary
MGF_CMD = '/opt/pwiz/msconvert --mgf'

# URLs 
 SEARCH_URL = 'http://bioinf.itmat.upenn.edu/mascot/cgi/nph-mascot.exe?1'
 DAT_URL = 'http://bioinf.itmat.upenn.edu/mascot/x-cgi/ms-status.exe?Autorefresh=false&Show=RESULTFILE&BrowserSafe=false'


# SEARCH_URL = 'http://www.matrixscience.com/cgi/nph-mascot.exe?1'
# DAT_URL = 'http://www.matrixscience.com/cgi/export_dat_2.pl'

#holder for stdout from exec
out = ''

#list of output files
outputs = Array.new

#lets get input files from command line
options = {}

OptionParser.new do |opts|
  
  opts.banner = "Usage: run_mascot.rb --input_files=<file1,file2>> [--params_file=mascot.par]"

  opts.on("--params_file=MANDATORY", "--params_file MANDATORY", "Params File") do |v|
    options[:params_file] = v
  end
  
   opts.on("--input_files=MANDATORY", "--input_fies MANDATORY", "Input Files") do |v|
     options[:input_files] = v
   end
  
end.parse!

# loop through each input file and run command
# redirects error to error file and then captures error

error = ''

begin
  
  ##################################################################################################
  #
  #   we do all the work in a begin / rescue block just in case there are any unforseen exceptions.  
  #   this way anything that goes wrong is caught and passed back to qips-node daemon
  #

  ## First set params
  params_file = ''
  
  if options[:params_file]
    
    #check file
    if File.exist?(options[:params_file])
      params_file = options[:params_file]
    else
      throw "PARAMS FILE NOT FOUND: #{options[:params_file]}\n"
    end
      
  else
    
    # try to find a params file if not specified 
    a = Dir.glob("*.par")
    if a.empty?
      out += "Could not find mascot params file. Will use default params.\n "
    else
      params_file = a[0]
    end
    
  end

  out += "Using Params file: #{params_file}\n" unless params_file == ''

  # now prepare http header params from params files

  mascotparams = { 'INTERMEDIATE' => '',
    'FORMVER' => '1.01',
    'SEARCH'=> 'MIS',
    'IATOL' => '0',
    'IASTOL' => '0',
    'IA2TOL' => '0',
    'IBTOL' => '1', 
    'IBSTOL' => '0',
    'IB2TOL' => '1',
    'IYTOL' => '1', 
    'IYSTOL' => '0',
    'IY2TOL' => '1', 
    'PEAK' => 'AUTO',
    'LTOL' => '',
    'REPTYPE' => 'peptide',
    'ERRORTOLERANT' => '0',
    'SHOWALLMODS' => '' }
  
  unless params_file == ''
    File.open(params_file) do |f|
      f.each do |line|
        if line =~ /^(.+)=(.*)/
          mascotparams[$1] = $2
        end
      end
    end
  end

  out += "Searching #{options[:input_files].split(',').size} input files...\n"
  
  #loop through each input file

  options[:input_files].split(',').each do |f|
    out += "Processing #{f}..."
    infile = ''

    if f =~ /(\.mzXML)/i || f =~ /(\.mzML)/i
      # convert first!
      out += "Converting #{f} first\n"
      out += `#{MGF_CMD} #{f}`
      infile = "#{File.basename(f, $1)}.mgf"
      
    else  
      infile = f
    end
    
    # out html from mascot server
    mascotout = File.open("MASCOT_#{File.basename(infile,'.mgf')}.html", "w+")

    out += "Sending #{infile} to mascot server\n"
    
    mascotparams['FILE'] = File.new(infile)
    
    # post
    body = ''
    RestClient.post(SEARCH_URL, mascotparams) { |response| body = response.to_s }
    
    #finally write body to output file to 
    mascotout.write(body)
    mascotout.close
    outputs << "MASCOT_#{File.basename(infile,'.mgf')}.html"
    
    # now fetch dat file and rename to match infile
    
    if body =~ /<A HREF.*?file=\.\.\/data\/(.+?\.dat)/ then
      
      # get date dir and basename 
      dat_basename = File.basename($1)
      pa = $1.split('/')
      date_dir = pa[pa.length-2]

      out += "Fetching #{$1} from mascot server and renaming\n"
      
      fetch_hash = {}
      fetch_hash['do_export'] = '1'
      fetch_hash['export_format'] = 'MascotDAT'
      fetch_hash['file'] = "../data/#{date_dir}/#{dat_basename}"

      outfile = File.open("#{File.basename(infile,'.mgf')}.dat","w+")
      
      if DAT_URL =~ /bioinf/
      
        # workaround!
        c = Curl::Easy.http_get "#{DAT_URL}&DateDir=#{date_dir}&ResJob=#{dat_basename}"
        outfile.write c.body_str
        outfile.write "\n"
        # out += c.body_str
        
      else
            
        RestClient.get(DAT_URL, fetch_hash) { |res|
      
          out += res.to_s
          outfile.write res.to_s
        
        }
      
      end
      
      outfile.close
      outputs << "#{File.basename(infile,'.mgf')}.dat"

    else

      # can't get datfile so throw an error
      error += "ERROR:  Could not find a dat file in mascot search results for #{infile}\n\n"
      error += "MASCOT OUT SOURCE: #{body}\n\n"

    end

  end

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

