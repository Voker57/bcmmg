db_version_hash = Wannabe.find('state', 'name' => 'version')
db_version = if !db_version_hash
	db_version_hash = Wannabe.new('state', 'name' => 'version')
	0
else
	db_version_hash["value"]
end


migrations = [
	lambda do 
		Wannabe.select('bets', "state" => nil) do |bet|
			bet["state"] = "open"
			bet.save
		end
	end,
	lambda do 
		Wannabe.create_index('users', 'jid')
		Wannabe.create_index('users', 'spent')
		Wannabe.create_index('state', 'name')
		Wannabe.create_index('bet', 'id')
		Wannabe.create_index('bet', 'amount')
		Wannabe.create_index('bet', 'from')
		Wannabe.create_index('bet', 'to')
		Wannabe.create_index('bet', 'created_at')
	end,
	lambda do 
		puts "Migrating to version 3..."
		Wannabe.select('bets', {}) do |bet|
			bet["amount"] = (bet["amount"] * 1000).to_i
			bet.save
		end
		Wannabe.select('users', {}) do |user|
			user["spent"] = (user["spent"] * 1000).to_i
 			user.save
		end
	end,
	lambda do 
		Wannabe.drop_indexes('bets')
		Wannabe.create_index('bets', 'id')
		Wannabe.create_index('bets', 'amount')
		Wannabe.create_index('bets', 'from')
		Wannabe.create_index('bets', 'to')
		Wannabe.create_index('bets', 'created_at')
	end,
	lambda do 
		Wannabe.drop_indexes('bet')
	end,
	lambda do
		Wannabe.select('users', "nick" => nil) do |user|
			user["nick"] = genname
 			user.save
		end
	end]

while db_version <= (migrations.size - 1)
	puts "Migrating to version #{db_version + 1}..."
	migrations[db_version].call
	db_version += 1
end

db_version_hash["value"] = db_version
db_version_hash.save