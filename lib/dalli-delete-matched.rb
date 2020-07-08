require 'active_support/cache/dalli_store'
require 'active_support/core_ext/module/aliasing'

ActiveSupport::Cache::DalliStore.class_eval do

  alias_method :old_write_entry, :write_entry
  def write_entry(key, entry, options)
    ret = old_write_entry(key, entry, options)
    doc = { hostnames: hostnames, key: key }
    mongoid_memcached.update_one(doc, doc, { upsert: true })
    ret
  end

  alias_method :old_delete_entry, :delete_entry
  def delete_entry(key, options)
    ret = old_delete_entry(key, options)
    mongoid_memcached.delete_one({ hostnames: hostnames, key: key })
    ret
  end

  alias_method :old_clear, :clear
  def clear(options=nil)
    ret = old_clear(options)
    mongoid_memcached.delete_many({ hostnames: hostnames })
    ret
  end

  def delete_matched(matcher, options = {})
    docs = mongoid_memcached.find({ hostnames: hostnames, key: /#{matcher}/ })
    docs.each { |doc| old_delete_entry(doc[:key], options) }
    mongoid_memcached.delete_many({ hostnames: hostnames, key: /#{matcher}/ }).deleted_count
  end

  private

  def mongoid_memcached
    @mongoid_memcached ||= Mongoid.default_client.database[:memcached].tap do |mongoid_memcached|
      mongoid_memcached.indexes.create_one({ hostnames: 1, key: 1 }, { unique: true })
    end
  end

  def hostnames
    @hostnames ||= stats.keys.join(',')
  end

end
