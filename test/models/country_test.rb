require "test_helper"

class CountryTest < ActiveSupport::TestCase
  # Sorteio sem dificuldade: nunca deve retornar pacifica (excluded), mas pode
  # retornar qualquer um dos três países jogáveis. Repetimos para reduzir a
  # chance de um resultado só ser coincidência do RNG.
  test "random sem dificuldade nunca sorteia um país excluded" do
    playable_ids = [ countries(:atlantis).id, countries(:edenia).id, countries(:draconia).id ]

    20.times do
      country = Country.random
      assert_not_nil country
      assert_includes playable_ids, country.id
      assert_not_equal countries(:pacifica).id, country.id
    end
  end

  test "random com difficulty easy só sorteia edenia" do
    5.times do
      assert_equal countries(:edenia), Country.random(difficulty: :easy)
    end
  end

  test "random com difficulty hard só sorteia draconia" do
    5.times do
      assert_equal countries(:draconia), Country.random(difficulty: :hard)
    end
  end

  # draconia é o único país hard jogável; se ele também ficar indisponível,
  # o tier "hard" fica vazio e o sorteio deve cair de volta para o pool
  # completo de jogáveis (nunca retornar pacifica, que é excluded).
  test "random com tier vazio cai de volta para o pool completo de jogáveis" do
    countries(:draconia).update!(excluded: true)
    playable_ids = [ countries(:atlantis).id, countries(:edenia).id ]

    10.times do
      country = Country.random(difficulty: :hard)
      assert_not_nil country
      assert_includes playable_ids, country.id
      assert_not_equal countries(:pacifica).id, country.id
      assert_not_equal countries(:draconia).id, country.id
    end
  end

  test "random retorna nil (não levanta exceção) quando não há país jogável" do
    Country.update_all(excluded: true)

    assert_nil Country.random
    assert_nil Country.random(difficulty: :easy)
  end
end
