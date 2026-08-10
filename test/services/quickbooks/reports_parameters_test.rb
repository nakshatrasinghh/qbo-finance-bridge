require "test_helper"

class QuickbooksReportsParametersTest < ActiveSupport::TestCase
  test "default period remains valid on a month end" do
    parameters =
      Quickbooks::Reports::Parameters.build(
        report_type: :profit_and_loss,
        today: Date.new(2026, 8, 31)
      )

    assert_equal Date.new(2026, 2, 28), parameters.start_date
    assert_equal Date.new(2026, 8, 31), parameters.end_date
  end

  test "period cannot start before the six month boundary" do
    error =
      assert_raises(Quickbooks::Error::Validation) do
        Quickbooks::Reports::Parameters.build(
          report_type: :profit_and_loss,
          attributes: {
            start_date: "2026-02-27",
            end_date: "2026-08-31"
          }
        )
      end

    assert_equal "quickbooks_report_parameters_invalid", error.code
  end
end
