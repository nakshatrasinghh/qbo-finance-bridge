module Quickbooks
  module JournalEntries
    class ReadPage < Data.define(:records, :parameters, :has_more)
      def pagination
        {
          page: parameters.page,
          per_page: parameters.per_page,
          returned_count: records.length,
          has_more: has_more,
          next_page: has_more ? parameters.page + 1 : nil
        }
      end

      def filters
        parameters.filters
      end
    end
  end
end
