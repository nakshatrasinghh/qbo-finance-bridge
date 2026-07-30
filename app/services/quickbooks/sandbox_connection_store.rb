module Quickbooks
  class SandboxConnectionStore
    LockEntry = Struct.new(:mutex, :users)

    def self.configured
      Rails.application.config.x.quickbooks.sandbox_connection_store ||
        raise(
          Error::Configuration.new(
            "The process-local QuickBooks connection store is not configured.",
            code: "quickbooks_connection_store_not_configured",
            http_status: :service_unavailable
          )
        )
    end

    def initialize
      @connections = ActiveSupport::Cache::MemoryStore.new(coder: nil)
      @lock_registry = {}
      @lock_registry_mutex = Mutex.new
    end

    def create(realm_id:, token_set:)
      loop do
        connection =
          SandboxConnection.new(
            id: SecureRandom.uuid,
            realm_id:,
            access_token: token_set.access_token,
            refresh_token: token_set.refresh_token,
            access_token_expires_at: token_set.access_token_expires_at,
            refresh_token_expires_at: token_set.refresh_token_expires_at
          )
        if connections.write(cache_key(connection.id), connection, unless_exist: true)
          return connection
        end
      end
    end

    def fetch(connection_id)
      return unless valid_connection_id?(connection_id)

      connections.read(cache_key(connection_id))
    end

    def fetch!(connection_id)
      fetch(connection_id) || raise_reconnect_required!
    end

    def refresh(connection:, force: false)
      synchronize(connection.id) do
        current = fetch!(connection.id)
        return current if tokens_rotated?(current, connection) && !current.access_token_expired?
        return current unless force || current.access_token_expired?

        replacement = current.with_refreshed_tokens(token_set: yield(current))
        connections.write(cache_key(current.id), replacement)
        replacement
      end
    end

    def disconnect(connection_id)
      synchronize(connection_id) do
        connection = fetch!(connection_id)
        yield(connection)
        connections.delete(cache_key(connection_id))
        connection
      end
    end

    def inspect
      "#<#{self.class.name} storage=process-local connections=[FILTERED]>"
    end

    private

    attr_reader :connections, :lock_registry, :lock_registry_mutex

    # Users counts the lock owner and all waiters. The registry entry is removed
    # only after no thread can still enter this connection's critical section.
    def synchronize(connection_id)
      raise_reconnect_required! unless valid_connection_id?(connection_id)

      entry =
        lock_registry_mutex.synchronize do
          lock_registry[connection_id] ||= LockEntry.new(Mutex.new, 0)
          lock_registry.fetch(connection_id).tap { |lock| lock.users += 1 }
        end
      entry.mutex.synchronize { yield }
    ensure
      release_lock(connection_id, entry) if entry
    end

    def release_lock(connection_id, entry)
      lock_registry_mutex.synchronize do
        entry.users -= 1
        lock_registry.delete(connection_id) if entry.users.zero?
      end
    end

    def tokens_rotated?(current, expected)
      !same_tokens?(current, expected)
    end

    def same_tokens?(left, right)
      left.access_token == right.access_token && left.refresh_token == right.refresh_token
    end

    def valid_connection_id?(connection_id)
      connection_id.is_a?(String) && connection_id.match?(SandboxConnection::ID_FORMAT)
    end

    def cache_key(connection_id)
      "quickbooks:sandbox_connection:#{connection_id}"
    end

    def raise_reconnect_required!
      raise Error::ReconnectRequired.new(
              "The QuickBooks sandbox connection is missing or expired. Reconnect QuickBooks.",
              code: "quickbooks_reconnect_required",
              http_status: :unauthorized
            )
    end
  end
end
