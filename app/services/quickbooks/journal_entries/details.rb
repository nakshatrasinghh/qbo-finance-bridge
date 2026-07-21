module Quickbooks
  module JournalEntries
    Line = Data.define(:posting_type, :amount, :account_id, :account_name, :description)

    class Details < Data.define(:id, :txn_date, :doc_number, :memo, :lines)
      def self.from_payload(payload)
        lines =
          Array(payload["Line"])
            .filter_map do |line|
              next unless line.is_a?(Hash) && line["DetailType"] == "JournalEntryLineDetail"

              detail = line["JournalEntryLineDetail"]
              account_ref = detail["AccountRef"] if detail.is_a?(Hash)
              amount = BigDecimal(line["Amount"].to_s, exception: false)
              next unless detail.is_a?(Hash) && account_ref.is_a?(Hash) && amount

              Line.new(
                posting_type: detail["PostingType"].to_s,
                amount: amount,
                account_id: account_ref["value"].to_s,
                account_name: account_ref["name"].presence,
                description: line["Description"].presence
              )
            end
            .freeze

        new(
          id: payload["Id"].to_s,
          txn_date: payload["TxnDate"].to_s,
          doc_number: payload["DocNumber"].presence,
          memo: payload["PrivateNote"].presence,
          lines: lines
        )
      end

      def balanced?
        total_for("Debit") == total_for("Credit") && total_for("Debit").positive?
      end

      private

      def total_for(posting_type)
        lines.sum(0.to_d) { |line| line.posting_type == posting_type ? line.amount : 0.to_d }
      end
    end
  end
end
