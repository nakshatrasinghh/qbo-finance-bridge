class QuickbooksSyncOperation < ApplicationRecord
  IDEMPOTENCY_KEY_FORMAT =
    /\A[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
  ENTITY_ID_FORMAT = /\A[a-z0-9_.:-]{1,255}\z/i
  OPERATION_ENTITY_TYPES = {
    "journal_entry_create" => "JournalEntry",
    "employee_create" => "Employee",
    "time_activity_create" => "TimeActivity",
    "tax_code_create" => "TaxCode",
    "inventory_item_create" => "Item",
    "customer_create" => "Customer",
    "vendor_create" => "Vendor",
    "invoice_create" => "Invoice",
    "bill_create" => "Bill",
    "customer_payment_create" => "Payment",
    "bill_payment_create" => "BillPayment"
  }.freeze
  OPERATION_TYPES = OPERATION_ENTITY_TYPES.keys.freeze
  STATUSES = %w[pending succeeded rejected uncertain].freeze

  belongs_to :quickbooks_connection

  validates :operation_type, inclusion: { in: OPERATION_TYPES }
  validates :idempotency_key,
            presence: true,
            length: {
              maximum: 50
            },
            format: {
              with: IDEMPOTENCY_KEY_FORMAT
            }
  validates :request_digest, presence: true, format: { with: /\A[0-9a-f]{64}\z/ }
  validates :request_payload, presence: true
  validates :status, inclusion: { in: STATUSES }
  validates :quickbooks_entity_type, inclusion: { in: OPERATION_ENTITY_TYPES.values }
  validates :quickbooks_entity_id, format: { with: ENTITY_ID_FORMAT }, allow_nil: true
  validates :quickbooks_entity_id, :result_payload, presence: true, if: :succeeded?
  validates :error_code, presence: true, if: :failed?
  validates :error_code, absence: true, unless: :failed?
  validates :completed_at, presence: true, unless: :pending?
  validates :completed_at, absence: true, if: :pending?
  validate :payloads_are_objects
  validate :operation_matches_entity_type
  validate :state_payload_is_consistent

  def pending?
    status == "pending"
  end

  def succeeded?
    status == "succeeded"
  end

  def failed?
    status.in?(%w[rejected uncertain])
  end

  private

  def payloads_are_objects
    errors.add(:request_payload, "must be a JSON object") unless request_payload.is_a?(Hash)
    errors.add(:result_payload, "must be a JSON object") unless result_payload.is_a?(Hash)
  end

  def operation_matches_entity_type
    return if OPERATION_ENTITY_TYPES[operation_type] == quickbooks_entity_type

    errors.add(:quickbooks_entity_type, "does not match the operation type")
  end

  def state_payload_is_consistent
    if status.in?(%w[pending rejected]) && quickbooks_entity_id.present?
      errors.add(:quickbooks_entity_id, "must be absent for pending or rejected operations")
    end

    return if succeeded? || !result_payload.is_a?(Hash) || result_payload.empty?

    errors.add(:result_payload, "must be empty unless the operation succeeded")
  end
end
