class CreateRoomPlayers < ActiveRecord::Migration[7.2]
  def change
    create_table :room_players do |t|
      t.references :room, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :score, null: false, default: 0
      t.datetime :joined_at, null: false

      t.timestamps
    end
    add_index :room_players, [ :room_id, :user_id ], unique: true
  end
end
