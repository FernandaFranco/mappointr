class CreateGameRounds < ActiveRecord::Migration[7.2]
  def change
    create_table :game_rounds do |t|
      t.references :user, null: false, foreign_key: true
      t.references :country, null: false, foreign_key: true
      t.decimal :guessed_lat
      t.decimal :guessed_lng
      t.integer :distance_km
      t.integer :time_seconds
      t.boolean :correct

      t.timestamps
    end
  end
end
