require "test_helper"
require "timeout"

class QuickbooksSandboxConnectionStoreTest < ActiveSupport::TestCase
  setup { @store = Quickbooks::SandboxConnectionStore.new }

  test "latest created connection becomes current without deleting browser handles" do
    first = @store.create(realm_id: "123", token_set: token_set("first"))
    second = @store.create(realm_id: "456", token_set: token_set("second"))

    assert_equal second.id, @store.fetch_current.id
    assert_equal first.id, @store.fetch(first.id).id
  end

  test "disconnect clears current only when it matches" do
    first = @store.create(realm_id: "123", token_set: token_set("first"))
    second = @store.create(realm_id: "456", token_set: token_set("second"))

    @store.disconnect(first.id) {}
    assert_equal second.id, @store.fetch_current.id

    @store.disconnect(second.id) {}
    assert_nil @store.fetch_current
  end

  test "evict clears current without revocation" do
    connection = @store.create(realm_id: "123", token_set: token_set("current"))

    assert_equal connection, @store.evict(connection.id)
    assert_nil @store.fetch(connection.id)
    assert_nil @store.fetch_current
  end

  test "fetch current bang raises reconnect when absent" do
    error = assert_raises(Quickbooks::Error::ReconnectRequired) { @store.fetch_current! }

    assert_equal "quickbooks_reconnect_required", error.code
  end

  test "refresh rejection evicts before a waiting refresh can replace the connection" do
    connection = @store.create(realm_id: "123", token_set: token_set("expired"))
    rejection_started = Queue.new
    release_rejection = Queue.new
    rejecting_refresh = reject_refresh(connection, rejection_started, release_rejection)

    rejection_started.pop
    waiting_refresh = refresh_after_rejection(connection)
    wait_until_blocked(waiting_refresh)
    release_rejection << true

    assert_instance_of Quickbooks::Error::Authentication, rejecting_refresh.value
    assert_instance_of Quickbooks::Error::ReconnectRequired, waiting_refresh.value
    assert_nil @store.fetch(connection.id)
    assert_nil @store.fetch_current
  ensure
    release_rejection&.push(true)
    [rejecting_refresh, waiting_refresh].compact.each { |thread| thread.join(1) || thread.kill }
  end

  private

  def token_set(marker)
    Quickbooks::Oauth::TokenSet.new(
      access_token: "access-#{marker}",
      refresh_token: "refresh-#{marker}",
      access_token_expires_at: 1.hour.from_now,
      refresh_token_expires_at: 100.days.from_now
    )
  end

  def reject_refresh(connection, started, release)
    Thread.new do
      @store.refresh(connection:, force: true) do
        started << true
        release.pop
        fail authentication_error
      end
    rescue Quickbooks::Error => error
      error
    end
  end

  def refresh_after_rejection(connection)
    Thread.new do
      @store.refresh(connection:, force: true) { token_set("replacement") }
    rescue Quickbooks::Error => error
      error
    end
  end

  def wait_until_blocked(thread)
    Timeout.timeout(1) { Thread.pass until thread.status == "sleep" }
  end

  def authentication_error
    Quickbooks::Error::Authentication.new(
      "QuickBooks authorization failed.",
      code: "invalid_grant",
      http_status: :unauthorized
    )
  end
end
