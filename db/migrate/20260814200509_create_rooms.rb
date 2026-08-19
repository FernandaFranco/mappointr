class CreateRooms < ActiveRecord::Migration[7.2]
  def change
    create_table :rooms do |t|
      t.string :code, null: false
      t.references :host, null: false, foreign_key: { to_table: :users }
      t.integer :status, null: false, default: 0
      t.integer :total_rounds, null: false, default: 5
      t.integer :current_round_number, null: false, default: 0
      t.integer :round_duration_seconds, null: false, default: 45
      t.integer :difficulty
      t.datetime :last_activity_at, null: false

      t.timestamps
    end
    add_index :rooms, :code, unique: true
    add_index :rooms, :status
  end
end
