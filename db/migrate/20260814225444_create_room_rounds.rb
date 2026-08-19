class CreateRoomRounds < ActiveRecord::Migration[7.2]
  def change
    create_table :room_rounds do |t|
      t.references :room, null: false, foreign_key: true
      t.references :country, null: false, foreign_key: true
      t.integer :round_number, null: false
      t.integer :status, null: false, default: 0
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end
    add_index :room_rounds, [ :room_id, :round_number ], unique: true
    add_index :room_rounds, :status
  end
end
