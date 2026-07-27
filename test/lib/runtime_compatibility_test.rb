require "test_helper"

class RuntimeCompatibilityTest < ActiveSupport::TestCase
  test "runs the repository Ruby version" do
    assert_equal Rails.root.join(".ruby-version").read.strip, RUBY_VERSION
  end

  test "connects to PostgreSQL" do
    result = ActiveRecord::Base.connection.select_value("SELECT 1")

    assert_equal 1, result.to_i
  end

  test "validates sandbox QuickBooks configuration without an external request" do
    configuration = Quickbooks::Configuration.new

    assert_same configuration, configuration.validate!
    assert_equal "sandbox", configuration.environment
    assert_equal Quickbooks::Configuration::SANDBOX_API_BASE_URL, configuration.api_base_url
  end
end
