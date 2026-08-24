class AddGuestToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :guest, :boolean, null: false, default: false
    add_index :users, :guest
    add_column :users, :display_name, :string
  end
end
