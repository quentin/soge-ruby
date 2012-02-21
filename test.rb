require 'yaml'
require 'lib/bank'

class Float
  # round to n decimals
  def round n
    (self * (10**n)).to_i / (10**n).to_f
  end
end

unless File.exists?(".sogeconf")
  STDERR.puts "Configuration file missing. Please create a `.sogeconf` file with the following content:"
  STDERR.puts "\ncodecli: CODECLIENT"
  STDERR.puts "pass: MOTDEPASSE\n\n"
  exit 1
end

File.open(".sogeconf","r") do |f|
  config = YAML.load(f)

  if (config['codecli'] == 'CODECLI') || (config['pass'] == 'PASS')
    STDERR.puts "Please edit `.sogeconf`."
    exit 1
  end

  soge = Bank::SocieteGenerale::Identite.new(config['codecli'], config['pass'])
  soge.accounts.each do |acc|
    puts acc.to_s

    puts "SOLDE: #{acc.solde.round(2)} #{acc.currency}"
    puts "BALANCE QUOTIDIENNE:"
    bydate = acc.operations.group_by{|op| op.date}
    bydate.keys.sort.reverse.each do |date|
      datesum = bydate[date].inject(0.0){|sum,op| sum + op.amount} 
      puts "#{date.strftime("%F")} #{"%.2f" % datesum}"
    end
  end
end
