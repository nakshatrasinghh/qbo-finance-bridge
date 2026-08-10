require "test_helper"

class QuickbooksRecordOrderingTest < ActiveSupport::TestCase
  class StubClient
    def initialize(response)
      @response = response
    end

    def get(*)
      @response
    end
  end

  test "record queries sort opaque IDs as strings" do
    expected_ids = %w[A 2 10]

    assert_equal expected_ids,
                 ordered_ids(Quickbooks::Invoices::RecordsQuery, "Invoice", invoice_payloads)
    assert_equal expected_ids, ordered_ids(Quickbooks::Bills::RecordsQuery, "Bill", bill_payloads)
    assert_equal expected_ids,
                 ordered_ids(
                   Quickbooks::CustomerPayments::RecordsQuery,
                   "Payment",
                   customer_payment_payloads
                 )
    assert_equal expected_ids,
                 ordered_ids(
                   Quickbooks::BillPayments::RecordsQuery,
                   "BillPayment",
                   bill_payment_payloads
                 )
  end

  private

  def ordered_ids(query_class, entity_name, payloads)
    client = StubClient.new("QueryResponse" => { entity_name => payloads })
    query_class.new(connection: nil, client: client).call.map(&:id)
  end

  def invoice_payloads
    opaque_ids.map do |id|
      {
        "Id" => id,
        "TxnDate" => "2026-08-10",
        "DueDate" => "2026-08-31",
        "CustomerRef" => {
          "value" => "customer-1"
        },
        "TotalAmt" => "1.00",
        "Balance" => "1.00",
        "Line" => []
      }
    end
  end

  def bill_payloads
    opaque_ids.map do |id|
      {
        "Id" => id,
        "TxnDate" => "2026-08-10",
        "DueDate" => "2026-08-31",
        "VendorRef" => {
          "value" => "vendor-1"
        },
        "APAccountRef" => {
          "value" => "payable-1"
        },
        "TotalAmt" => "1.00",
        "Balance" => "1.00",
        "Line" => []
      }
    end
  end

  def customer_payment_payloads
    opaque_ids.map do |id|
      {
        "Id" => id,
        "TxnDate" => "2026-08-10",
        "CustomerRef" => {
          "value" => "customer-1"
        },
        "TotalAmt" => "1.00",
        "UnappliedAmt" => "1.00",
        "Line" => []
      }
    end
  end

  def bill_payment_payloads
    opaque_ids.map do |id|
      {
        "Id" => id,
        "TxnDate" => "2026-08-10",
        "VendorRef" => {
          "value" => "vendor-1"
        },
        "PayType" => "Check",
        "CheckPayment" => {
          "BankAccountRef" => {
            "value" => "bank-1"
          }
        },
        "TotalAmt" => "1.00",
        "Line" => []
      }
    end
  end

  def opaque_ids
    %w[10 2 A]
  end
end
