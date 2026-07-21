class AccountMapping < ApplicationRecord
  MAX_BULK_LOOKUP_SIZE = 1_000

  belongs_to :quickbooks_connection

  normalizes :source_system,
             :source_account_code,
             :source_account_name,
             :quickbooks_account_id,
             :quickbooks_account_name,
             :quickbooks_account_type,
             with: ->(value) { value.to_s.strip }
  normalizes :quickbooks_account_subtype, with: ->(value) { value.to_s.strip.presence }

  validates :source_system, presence: true, length: { maximum: 100 }
  validates :source_account_code,
            presence: true,
            length: {
              maximum: 100
            },
            uniqueness: {
              scope: %i[quickbooks_connection_id source_system]
            }
  validates :source_account_name, presence: true, length: { maximum: 255 }
  validates :quickbooks_account_id, presence: true, length: { maximum: 255 }
  validates :quickbooks_account_name, presence: true, length: { maximum: 255 }
  validates :quickbooks_account_type, presence: true, length: { maximum: 100 }
  validates :quickbooks_account_subtype, length: { maximum: 100 }, allow_nil: true
  validates :last_verified_at, presence: true

  def self.indexed_by_source_account_code(connection:, source_system:, source_account_codes:)
    normalized_system = source_system.to_s.strip
    normalized_codes =
      Array(source_account_codes).filter_map { |code| code.to_s.strip.presence }.uniq

    if normalized_codes.length > MAX_BULK_LOOKUP_SIZE
      raise ArgumentError, "source_account_codes cannot exceed #{MAX_BULK_LOOKUP_SIZE} entries"
    end

    where(
      quickbooks_connection: connection,
      source_system: normalized_system,
      source_account_code: normalized_codes
    ).index_by(&:source_account_code)
  end
end
