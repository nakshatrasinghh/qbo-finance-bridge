class CreateAccountMappings < ActiveRecord::Migration[8.1]
  def change
    create_table :account_mappings do |t|
      t.references :quickbooks_connection, null: false, foreign_key: true
      t.string :source_system, null: false
      t.string :source_account_code, null: false
      t.string :source_account_name, null: false
      t.string :quickbooks_account_id, null: false
      t.string :quickbooks_account_name, null: false
      t.string :quickbooks_account_type, null: false
      t.string :quickbooks_account_subtype
      t.datetime :last_verified_at, null: false

      t.timestamps
    end

    add_index :account_mappings,
              %i[quickbooks_connection_id source_system source_account_code],
              unique: true,
              name: "index_account_mappings_on_connection_source"
    add_index :account_mappings,
              %i[quickbooks_connection_id quickbooks_account_id],
              name: "index_account_mappings_on_connection_qbo_account"

    add_check_constraint :account_mappings,
                         "char_length(btrim(source_system)) BETWEEN 1 AND 100",
                         name: "account_mappings_source_system_length"
    add_check_constraint :account_mappings,
                         "char_length(btrim(source_account_code)) BETWEEN 1 AND 100",
                         name: "account_mappings_source_code_length"
    add_check_constraint :account_mappings,
                         "char_length(btrim(source_account_name)) BETWEEN 1 AND 255",
                         name: "account_mappings_source_name_length"
    add_check_constraint :account_mappings,
                         "char_length(btrim(quickbooks_account_id)) BETWEEN 1 AND 255",
                         name: "account_mappings_qbo_id_length"
    add_check_constraint :account_mappings,
                         "char_length(btrim(quickbooks_account_name)) BETWEEN 1 AND 255",
                         name: "account_mappings_qbo_name_length"
    add_check_constraint :account_mappings,
                         "char_length(btrim(quickbooks_account_type)) BETWEEN 1 AND 100",
                         name: "account_mappings_qbo_type_length"
    add_check_constraint :account_mappings,
                         "quickbooks_account_subtype IS NULL OR char_length(btrim(quickbooks_account_subtype)) BETWEEN 1 AND 100",
                         name: "account_mappings_qbo_subtype_length"
  end
end
