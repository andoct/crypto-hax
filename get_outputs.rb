#!/usr/bin/env ruby

# rvm use 2.4.1

require 'active_support/core_ext/hash'
require "csv"
require 'json'
require 'net/http'
require 'optparse'
require 'pry'
require 'satoshi-unit'

require './bitcoin_rpc'

@UNMATCHED_IDENTIFIER = "X"
# Pry::ColorPrinter.pp transaction

def row_to_transaction(row)
  transaction = {
    id: row[0],
    created_at: row[1],
    wallet_address: row[2],
    tx_type: row[3],
    satoshis: row[4],
    blockchain_transaction_id: row[5],
    wallet_id: row[6],
    output_index: row[7],
    token: row[8],
    matched_index: row[9]
  }

  transaction[:matched_index] ||= @UNMATCHED_IDENTIFIER

  return transaction
end


rpc_endpoint = "http://#{ENV["RPC_USER"]}:#{ENV["RPC_PASSWORD"]}@127.0.0.1:8332"
puts "rpc_endpoint: #{rpc_endpoint}"
@bitcoin_rpc = BitcoinRPC.new(rpc_endpoint)
def get_outputs_from_core_node(transaction)

  # raw = @bitcoin_rpc.getrawtransaction "9a23b701a614b81746c0a44caa8b393844f94aaa8a13b57666a6813464e72f94"
  raw = @bitcoin_rpc.getrawtransaction transaction[:blockchain_transaction_id]
  response = @bitcoin_rpc.decoderawtransaction(raw).deep_symbolize_keys
  outputs = response[:vout]

  ## Fix long line
  matching_outputs = outputs.select do |output|
    blockchain_satoshis = Satoshi.new(output[:value])
    our_satoshis = Satoshi.new(transaction[:satoshis], from_unit: :satoshi)

    blockchain_output_addresses = output[:scriptPubKey][:addresses]
    our_address = transaction[:wallet_address]

    our_satoshis == blockchain_satoshis && blockchain_output_addresses.include?(our_address)
  end

  if matching_outputs.length != 1
    transaction[:matched_index] = @UNMATCHED_IDENTIFIER
    puts "Only 1 matching output is expected. matching_outputs: #{matching_outputs}. RESULT: #{transaction[:matched_index]} "
    puts
    puts
    puts "++++++++++++++++++++++++++++++++++++++++++"
    Pry::ColorPrinter.pp transaction
    puts "***************"
    Pry::ColorPrinter.pp outputs

    puts "++++++++++++++++++++++++++++++++++++++++++"
    puts
    puts

  else
    # puts "Found match! #{matching_outputs.first}"
    transaction[:matched_index] = matching_outputs.first[:n]
  end

end


def backfill_outputs(transactions, previously_saved_transactions, output_file)
  puts "Backfilling outputs"
  tick = Time.now
  last_index = 0

  transactions.each_with_index do |transaction, index|

    if Time.now - tick > 1
      puts "Processed #{index - last_index} records"
      tick = Time.now
      last_index = index
    end

    # Fix long long.
    matched_transaction = previously_saved_transactions.find { |existing| existing[:blockchain_transaction_id] == transaction[:blockchain_transaction_id]}

    ## make more ruby
    preexisting_match_index = @UNMATCHED_IDENTIFIER
    if matched_transaction
      preexisting_match_index = matched_transaction[:matched_index]
    end

    if preexisting_match_index != @UNMATCHED_IDENTIFIER
      transaction[:matched_index] = preexisting_match_index
    else
      get_outputs_from_core_node transaction
      sleep 0.001
    end

    CSV.open(output_file, "a") do |csv|
      csv << transaction.values
    end
  end
end


options = {
  :source_tsv => "",
  :dest_csv => ""
}
OptionParser.new do |opts|
  opts.banner = "Usage: get_outputs.rb --source source.tsv --dest ouputs.csv"

  opts.on("-s", "--source SOURCE_TSV", "Source data as TSV file (tab separated)") do |source_tsv|
    options[:source_tsv] = source_tsv
  end

  opts.on("-d", "--dest DEST_CSV", "CSV (comma separated) to output migrated data to") do |dest_csv|
    options[:dest_csv] = dest_csv
  end
end.parse!

if options[:source_tsv].empty?
  fail "SOURCE_TSV required!"
end

output_file = options[:dest_csv]
if output_file.empty?
  output_file = "migrated_outputs.tsv"
  puts "No destination CSV specified. Using default #{output_file}"
end

input_file = options[:source_tsv]
transactions = CSV.open(input_file, "r", { :col_sep => "\t" }).map { |row| row_to_transaction row }

headers = transactions.first
headers[:matched_index] = "matched_index"
puts "Header Row: #{headers}"
puts
# drop the header row
transactions.shift

puts "OUTPUT FILE: #{output_file}"

previously_saved_transactions = []
if File.file?(output_file)
  previously_saved_transactions = CSV.open(output_file, "r").map { |row| row_to_transaction row }
  puts "#{previously_saved_transactions.length - 1} transactions have already been processed. Re-using work." if previously_saved_transactions.length > 1
end


puts "Outputing data to #{output_file}"
CSV.open(output_file, "w") do |csv|
  csv << headers.values
  # transactions.each { |transaction| csv << transaction.values }
end

backfill_outputs(transactions, previously_saved_transactions, output_file)


# transactions.each { |transaction| puts transaction[:matched_index] }
# problematic_transactions = transactions.select { |transaction| transaction[:output_index] != transaction[:matched_index] }
# puts "Problematic Transactions: "
# Pry::ColorPrinter.pp problematic_transactions

# correct_transactions = transactions.select { |transaction| transaction[:output_index] == transaction[:matched_index] }
# puts "Correct Transactions: "
# Pry::ColorPrinter.pp correct_transactions

