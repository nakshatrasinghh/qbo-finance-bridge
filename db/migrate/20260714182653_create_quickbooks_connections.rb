class CreateQuickbooksConnections < ActiveRecord::Migration[8.1]
  def change
    create_table :quickbooks_connections do |t|
      t.string :realm_id, null: false
      t.string :environment, null: false
      t.string :status, null: false, default: "active"
      t.text :access_token
      t.text :refresh_token
      t.datetime :access_token_expires_at
      t.datetime :refresh_token_expires_at
      t.string :granted_scopes, null: false, default: "com.intuit.quickbooks.accounting"
      t.datetime :last_refreshed_at
      t.datetime :disconnected_at
      t.integer :lock_version, null: false, default: 0

      t.timestamps
    end

    add_index :quickbooks_connections, %i[environment realm_id], unique: true
    add_index :quickbooks_connections, :status
    add_check_constraint :quickbooks_connections,
                         "realm_id ~ '^[0-9]+$'",
                         name: "quickbooks_connections_realm_id_numeric"
    add_check_constraint :quickbooks_connections,
                         "char_length(realm_id) <= 255",
                         name: "quickbooks_connections_realm_id_length"
    add_check_constraint :quickbooks_connections,
                         "environment IN ('sandbox', 'production')",
                         name: "quickbooks_connections_environment_valid"
    add_check_constraint :quickbooks_connections,
                         "status IN ('active', 'disconnected')",
                         name: "quickbooks_connections_status_valid"
    add_check_constraint :quickbooks_connections,
                         <<~SQL.squish,
                           status <> 'active' OR (
                             access_token IS NOT NULL AND
                             refresh_token IS NOT NULL AND
                             access_token_expires_at IS NOT NULL
                           )
                         SQL
                         name: "quickbooks_connections_active_tokens_present"
    add_check_constraint :quickbooks_connections,
                         "status <> 'disconnected' OR disconnected_at IS NOT NULL",
                         name: "quickbooks_connections_disconnect_time_present"
    add_check_constraint :quickbooks_connections,
                         <<~SQL.squish,
                           status <> 'disconnected' OR (
                             access_token IS NULL AND
                             refresh_token IS NULL AND
                             access_token_expires_at IS NULL
                           )
                         SQL
                         name: "quickbooks_connections_disconnected_tokens_cleared"
  end
end
