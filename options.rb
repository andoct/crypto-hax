#!/usr/bin/env ruby

require 'optparse'

# ./get_outputs --source bitcoin_transaction_inputs.tsv --dest fixed_output.tsv

options = {
  :source_tsv => "",
  :dest_tsv => ""
}
OptionParser.new do |opts|
  opts.banner = "Usage: get_outputs.rb --source source.tsv --dest ouputs.tsv"

  opts.on("-s", "--source SOURCE_TSV", "Source data as TSV file") do |source_tsv|
    options[:source_tsv] = source_tsv
  end

  opts.on("-d", "--dest SOURCE_TSV", "TSV to output migrated data to") do |dest_tsv|
    options[:dest_tsv] = dest_tsv
  end

end.parse!

p options
p ARGV
