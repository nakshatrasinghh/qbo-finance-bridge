require "test_helper"

class HealthEndpointsTest < ActionDispatch::IntegrationTest
  test "Rails and application health endpoints respond successfully" do
    get "/up"
    assert_response :success

    get "/health"
    assert_response :success
    assert_equal({ "status" => "ok" }, response.parsed_body)
  end
end
