class QuickbooksConnection < ApplicationRecord
  ENVIRONMENTS = %w[sandbox production].freeze
  STATUSES = %w[active disconnected].freeze
  SENSITIVE_ATTRIBUTES = %w[access_token refresh_token].freeze

  encrypts :access_token
  encrypts :refresh_token

  has_many :account_mappings, dependent: :destroy
  has_many :quickbooks_sync_operations, dependent: :restrict_with_exception

  self.filter_attributes += SENSITIVE_ATTRIBUTES

  scope :connected, -> { where(status: "active") }

  validates :realm_id,
            presence: true,
            length: {
              maximum: 255
            },
            format: {
              with: /\A\d+\z/
            },
            uniqueness: {
              scope: :environment
            }
  validates :environment, inclusion: { in: ENVIRONMENTS }
  validates :status, inclusion: { in: STATUSES }
  validates :granted_scopes, presence: true
  validates :access_token, :refresh_token, :access_token_expires_at, presence: true, if: :connected?
  validates :access_token,
            :refresh_token,
            :access_token_expires_at,
            absence: true,
            if: :disconnected?
  validates :disconnected_at, presence: true, if: :disconnected?

  def connected?
    status == "active"
  end

  def disconnected?
    status == "disconnected"
  end

  def access_token_expired?(at: Time.current, skew: 1.minute)
    access_token_expires_at.blank? || access_token_expires_at <= at + skew
  end

  def store_authorization!(token_set:, scopes:)
    update!(
      status: "active",
      access_token: token_set.access_token,
      refresh_token: token_set.refresh_token,
      access_token_expires_at: token_set.access_token_expires_at,
      refresh_token_expires_at: token_set.refresh_token_expires_at,
      granted_scopes: scopes,
      last_refreshed_at: nil,
      disconnected_at: nil
    )
  end

  def store_refreshed_tokens!(token_set:)
    update!(
      access_token: token_set.access_token,
      refresh_token: token_set.refresh_token,
      access_token_expires_at: token_set.access_token_expires_at,
      refresh_token_expires_at: token_set.refresh_token_expires_at || refresh_token_expires_at,
      last_refreshed_at: Time.current
    )
  end

  def mark_disconnected!
    update!(
      status: "disconnected",
      access_token: nil,
      refresh_token: nil,
      access_token_expires_at: nil,
      refresh_token_expires_at: nil,
      disconnected_at: Time.current
    )
  end

  def serializable_hash(options = nil)
    super.except(*SENSITIVE_ATTRIBUTES)
  end
end
