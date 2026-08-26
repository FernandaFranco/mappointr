require "test_helper"

# public/world_boundaries.geojson é gerado por `bin/rails
# countries:export_boundaries` (chamado no fim de countries:import) e serve
# de fundo pro mapa no lugar de um tile server externo — ver
# app/javascript/world_boundaries.js. Esses testes rodam contra o arquivo já
# commitado, não regeneram nada: o objetivo é pegar regressão (arquivo
# apagado/gitignorado por engano, ou formato mudando) e provar que nenhuma
# propriedade de feature vaza o país antes do jogador chutar.
class WorldBoundariesTest < ActionDispatch::IntegrationTest
  test "GET /world_boundaries.geojson serve um FeatureCollection válido" do
    get "/world_boundaries.geojson"

    assert_response :success
    geojson = JSON.parse(response.body)

    assert_equal "FeatureCollection", geojson["type"]
    assert_not_empty geojson["features"]
  end

  test "as features não carregam properties que identifiquem o país" do
    get "/world_boundaries.geojson"
    geojson = JSON.parse(response.body)

    geojson["features"].each do |feature|
      assert_equal({}, feature["properties"],
        "uma feature com properties vazaria o país sorteado antes do jogador chutar")
    end
  end
end
