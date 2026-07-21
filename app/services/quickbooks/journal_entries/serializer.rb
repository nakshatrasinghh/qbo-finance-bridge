module Quickbooks
  module JournalEntries
    class Serializer
      def self.call(entry)
        {
          "id" => entry.id,
          "txn_date" => entry.txn_date,
          "doc_number" => entry.doc_number,
          "memo" => entry.memo,
          "balanced" => entry.balanced?,
          "lines" =>
            entry.lines.map do |line|
              {
                "posting_type" => line.posting_type,
                "amount" => line.amount.to_s("F"),
                "account_id" => line.account_id,
                "account_name" => line.account_name,
                "description" => line.description
              }
            end
        }
      end
    end
  end
end
