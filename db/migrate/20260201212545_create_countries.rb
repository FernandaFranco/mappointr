class CreateCountries < ActiveRecord::Migration[7.2]
  def change
    create_table :countries do |t|
      t.string :name, null: false
      t.string :name_pt, null: false
      t.integer :difficulty, default: 1

      # Colunas geográficas PostGIS
      # multi_polygon: fronteiras do país (pode ter múltiplos polígonos - ex: ilhas)
      # geographic: true significa usar coordenadas reais (lat/lng) em vez de planas
      # srid: 4326 é o sistema de coordenadas GPS (WGS84)
      t.multi_polygon :boundary, geographic: true, srid: 4326

      t.timestamps
    end

    # Índice espacial para buscas geográficas rápidas
    add_index :countries, :boundary, using: :gist

    # Índice para busca por nome
    add_index :countries, :name, unique: true
  end
end
