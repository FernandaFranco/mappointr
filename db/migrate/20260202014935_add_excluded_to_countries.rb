class AddExcludedToCountries < ActiveRecord::Migration[7.2]
  def change
    add_column :countries, :excluded, :boolean, default: false, null: false
  end
end
