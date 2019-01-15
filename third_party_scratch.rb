def set_transaction_outputs_from_blockchain(transaction)
  # curl https://blockchain.info/rawtx/1d2668bff478e738a4c3a96674d37f850f807484bbf6b3ff33f2c418eac7ec17
  uri = URI("https://blockchain.info/rawtx/" + transaction[:blockchain_transaction_id])
  response = Net::HTTP.get(uri)
  json = JSON.parse(response).with_indifferent_access

  outputs = json[:out]

  ## find the matching output_index. TODO: fix long line
  matching_outputs = outputs.select { |output| output[:addr] == transaction[:wallet_address] && output[:value] == transaction[:satoshis].to_i }

  if matching_outputs.length != 1
    puts "Only 1 matching output is expected. matching_outputs: #{matching_outputs} "
  else
    # puts "Found match! #{matching_outputs.first}"
    transaction[:matched_index] = matching_outputs.first[:n]
  end
end
