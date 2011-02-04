require 'rubygems'
require 'xmpp4r-simple'
require 'yaml'
require 'mongo'
require 'wannabe'

Wannabe.init('bcmmg')

class Array
	def rnd
		self[rand(self.size)]
	end
end

def genname
	vowels = %w|e y u i o a oo ou ea ae ia|
	unvowels = %w|w r t p s d f g h j k l z x c v b n m th ck wh ph|
	
	name = ""
	(rand(2) + 4).times do |i|
	case i % 2
	when 0
		name << (i == 0 ? vowels.rnd[0..0].upcase : vowels.rnd)
	when 1
		name << (i == 0 ? unvowels.rnd[0..0].upcase : unvowels.rnd)
	end
	end
	name
end

require 'migrations.rb'

default_config = {
	:min_confirmations => 3
	}

config = default_config.merge(YAML.load(File.read("config.yml")))
$config = config
client = Jabber::Simple.new(config[:jid], config[:password])
client.accept_subscriptions=true
$client = client

def user_balance(user)
	balance = `bitcoind getreceivedbyaddress #{user["address"]} #{$config[:min_confirmations]}`.strip.to_f * 1000
	balance - user["spent"]
end

def print_bet(bet)
	bet_user = Wannabe.find("users", bet["from"])
	"Bet #{bet["id"]}: #{bet["amount"]} mBC by #{bet_user["nick"]}"
end

loop do

client.received_messages.each do |m|
	puts "MESSAGE: #{m.from.strip}: #{m.body}"
	begin
	this_user = Wannabe.find("users", "jid" => m.from.strip.to_s)
	
	unless this_user
		this_user = Wannabe.new("users", { "jid" => m.from.strip.to_s, "spent" => -1, "address" => `bitcoind getnewaddress`.strip, "nick" => genname })
		this_user.save
		client.deliver(m.from.to_s, "Your bitcoin address is #{this_user["address"]}. Your balance is #{user_balance(this_user)} mBC. Your auto-generated nick is #{this_user["nick"]}, NICK anothernick to change it. Send HELP to get started.")
	end
	split_string = m.body.split(" ")
	command = split_string[0]
	args = split_string[1..-1]
	case
	when command == "HELLO"
		client.deliver(m.from.to_s, "Why, hello, #{this_user["jid"]}.")
 	when command == "ADDRESS"
 		client.deliver(m.from.to_s, "Your bitcoin address is #{this_user["address"]}")
 	when command == "BALANCE"
 		client.deliver(m.from.to_s, "Your current balance is #{user_balance(this_user)} mBC")
	when command == "TAKE"
		if args[0]
			bet_id = args[0]
			real_balance = user_balance(this_user)
			if ex_bet = Wannabe.find("bets", "id" => bet_id, "state" => "open")
				if ex_bet["from"] == this_user["_id"]
					this_user["spent"] -= ex_bet["amount"]
					ex_bet["state"] = "withdrawn"
					ex_bet.save
					this_user.save
					client.deliver(m.from.to_s, "Bet withdrawn")
				elsif ex_bet["amount"] <= real_balance
					to_user = Wannabe.find('users', ex_bet["to"])
					from_user = Wannabe.find('users', ex_bet["from"])
					if rand(2) == 0
						ex_bet["state"] = "wont"
						ex_bet.save
						to_user["spent"] -= ex_bet["amount"]
						to_user.save
						client.deliver(m.from.to_s, "You took bet #{ex_bet["id"]} and won #{ex_bet["amount"]} mBC!")
						client.deliver(from_user["jid"], "Congratulations, you lost bet #{ex_bet["id"]} (#{ex_bet["amount"]} mBC) to #{to_user["nick"]}!")
					else
						ex_bet["state"] = "wonf"
						ex_bet.save
						to_user["spent"] += ex_bet["amount"]
						to_user.save
						from_user["spent"] -= ex_bet["amount"] * 2
						from_user.save
						client.deliver(m.from.to_s, "You took bet ##{ex_bet["id"]} and lost #{ex_bet["amount"]} mBC!")
						client.deliver(from_user["jid"], "Congratulations, you won bet ##{ex_bet["id"]} (#{ex_bet["amount"]} mBC) against #{to_user["nick"]}!")
					end
				else
					client.deliver(m.from.to_s, "Congratulations, not enough money!")
				end
			else
				client.deliver(m.from.to_s, "Congratulations, no such bet!")
			end
		else
			client.deliver(m.from.to_s, "Congratulations, you didn't enter any bet ID!")
		end
	when command == "BET"
		if args[0].to_i > 0
			bet_size = args[0].to_i
			this_user = Wannabe.find("users", "jid" => m.from.strip.to_s)
			real_balance = user_balance(this_user)
			if bet_size <= real_balance
				bet_id = rand(666666).to_s(16)
				bet = Wannabe.new('bets', "id" => bet_id, "amount" => bet_size, "from" => this_user["_id"], "created_at" => DateTime.now.strftime("%s").to_i, "state" => "open")
				bet.save
				this_user["spent"] += bet_size
				this_user.save
				client.deliver(m.from.to_s, "New bet created: #{bet["id"]}")
			else
				client.deliver(m.from.to_s, "Not enough money")
			end
			
		else
			client.deliver(m.from.to_s, "Zero bet created OK!")
		end
	when command == "LSBETS"
		msg = "Last 10 bets"
		Wannabe.select('bets', {"state" => "open"}, :sort => ["created_at", :desc], :limit => 10) do |bet|
			msg << "\n" << print_bet(bet)
		end
		client.deliver(m.from.to_s, msg)
	when command == "HELP"
		msg = "Welcome to BitCoin MMG, the Money Making Game!

Money Making Game is simple -- you put up a bet, and then someone else pays the same amount that you put up to take the bet. Then one of you gets all of the money. Doesn't it sound fair?

Commands:

ADDRESS: Prints your personal bitcoin address. Send money there to add them to your balance.
BALANCE: Prints your current balance.
TAKE bet_id: Take other player's bet, or take back your own.
BET amount: Place a new bet. Fractions are not OK.
LSBETS: Get last 10 open bets.
NICK new_nick: Change nick
HELP: This help.

Examples:

BET 100
Make a new bet of 100 mBC

TAKE 0ffff
Take another player's bet 0ffff

Feedback:

voker57@gmail.com"
		client.deliver(m.from.to_s, msg)
	when command == "HALP"
		client.deliver(m.from.to_s, "SLM")
	when (command == "NICK" and args[0])
		new_nick = args[0]
		if Wannabe.find('users', {"nick" => new_nick})
			client.deliver(m.from.to_s, "Nick already taken")
		elsif ! (new_nick =~ /^[A-Za-z0-9]+$/)
			client.deliver(m.from.to_s, "Alphanumerics only please")
		else
			this_user["nick"] = new_nick
			this_user.save
			client.deliver(m.from.to_s, "Nick changed!")
		end
	when (command == "GIVE" and config[:admins].include? m.from.strip.to_s)
		user = Wannabe.find('users', "jid" => m.body.split(" ")[1])
		user["spent"] -= m.body.split(" ")[2].to_i
		user.save
		client.deliver(m.from.to_s, "Given! Now it's #{user_balance(user)}")
	else
		client.deliver(m.from.to_s, "No such command or wrong syntax. HELP for list.")
	end
# 	rescue Interrupt => e
#   		raise e
#  	rescue e
#  		client.deliver(m.from.to_s, "Oops! Exception occured. Don't worry, it'll be ok in the end.")
 	end
end

end