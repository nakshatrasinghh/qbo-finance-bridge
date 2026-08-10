require "test_helper"

class QuickbooksResponseDateValidationTest < ActiveSupport::TestCase
  class StubClient
    def initialize(response)
      @response = response
    end

    def get(*)
      @response
    end
  end

  test "journal entry query rejects an impossible transaction date" do
    client =
      StubClient.new(
        "QueryResponse" => {
          "JournalEntry" => [
            {
              "Id" => "journal-entry-1",
              "TxnDate" => "2026-99-99",
              "Line" => [
                {
                  "Amount" => "1.00",
                  "DetailType" => "JournalEntryLineDetail",
                  "JournalEntryLineDetail" => {
                    "PostingType" => "Debit",
                    "AccountRef" => {
                      "value" => "account-1"
                    }
                  }
                }
              ]
            }
          ]
        }
      )

    assert_raises(Quickbooks::Error::UnexpectedResponse) do
      Quickbooks::JournalEntries::Query.new(connection: nil, client: client).call
    end
  end

  test "time activity query rejects an impossible transaction date" do
    client =
      StubClient.new(
        "QueryResponse" => {
          "TimeActivity" => [
            {
              "Id" => "time-activity-1",
              "TxnDate" => "2026-99-99",
              "EmployeeRef" => {
                "value" => "employee-1"
              },
              "Hours" => 1,
              "Minutes" => 0
            }
          ]
        }
      )

    assert_raises(Quickbooks::Error::UnexpectedResponse) do
      Quickbooks::TimeActivities::Query.new(connection: nil, client: client).call
    end
  end
end
