require 'mongo'

class Wannabe
	@@db = nil
	
	def self.init(dbname)
		@@db = Mongo::Connection.new.db('dbname')
		return true
	end
	
	def self.find(where, *what)
		obj = @@db.collection(where).find_one(*what)
		if obj
			Wannabe.new(where, obj)
		else
			nil
		end
	end
	
	def self.clear(where)
		@@db.collection(where).drop
	end
	
	def self.select(where, *what, &block)
		@@db.collection(where).find(*what).each do |el|
			block.call(Wannabe.new(where, el))
		end
	end
	
	def self.create_index(where, *opts)
		@@db.collection(where).create_index(*opts)
	end
	
	def self.drop_index(where, *opts)
		@@db.collection(where).drop_index(*opts)
	end
	
	def self.drop_indexes(where)
		@@db.collection(where).drop_indexes
	end
	
	def initialize(where, hash)
		@data = hash || {}
		@where = where
	end
	
	def [](k)
		@data[k]
	end
	
	def []=(k,v)
		@data[k] = v
	end
	
	def save
		if @data["_id"]
			@@db.collection(@where).update({"_id" => @data["_id"]}, @data)
		else
			@@db.collection(@where).insert(@data)
		end
		return true
	end
	
	def destroy
		@@db.collection(@where).remove({"_id" => @data["_id"]})
	end
end