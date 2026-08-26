class RemoveDeviseFromUsers < ActiveRecord::Migration[8.1]
  # Migração de mão única: depois que email/senha somem, não tem como
  # reconstruir esses dados no down. Ver CLAUDE.md.
  def up
    User.reset_column_information
    User.where(display_name: [ nil, "" ]).find_each do |user|
      user.update_column(:display_name, "Visitante #{rand(1000..9999)}")
    end

    remove_column :users, :email
    remove_column :users, :encrypted_password
    remove_column :users, :reset_password_token
    remove_column :users, :reset_password_sent_at
    remove_column :users, :remember_created_at
    remove_column :users, :guest

    change_column_null :users, :display_name, false
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
