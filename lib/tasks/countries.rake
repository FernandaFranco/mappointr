# frozen_string_literal: true

namespace :countries do
  desc "Importa países do Natural Earth Data (GeoJSON)"
  task import: :environment do
    require "open-uri"
    require "json"

    puts "Baixando dados do Natural Earth..."

    # Natural Earth Data - países em escala 1:110m (simplificado, ~500KB)
    # Fonte oficial: https://www.naturalearthdata.com/
    geojson_url = "https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_110m_admin_0_countries.geojson"

    begin
      response = URI.open(geojson_url)
      data = JSON.parse(response.read)
    rescue OpenURI::HTTPError => e
      puts "Erro ao baixar dados: #{e.message}"
      exit 1
    end

    puts "Processando #{data['features'].length} países..."

    # Mapeamento de nomes para português (inclui abreviações do Natural Earth)
    portuguese_names = {
      # Américas
      "Brazil" => "Brasil",
      "Argentina" => "Argentina",
      "Chile" => "Chile",
      "Peru" => "Peru",
      "Colombia" => "Colômbia",
      "Venezuela" => "Venezuela",
      "Uruguay" => "Uruguai",
      "Paraguay" => "Paraguai",
      "Bolivia" => "Bolívia",
      "Ecuador" => "Equador",
      "United States of America" => "Estados Unidos",
      "Canada" => "Canadá",
      "Mexico" => "México",
      "Cuba" => "Cuba",
      "Jamaica" => "Jamaica",
      "Haiti" => "Haiti",
      "Dominican Republic" => "República Dominicana",
      "Dominican Rep." => "República Dominicana",
      "Puerto Rico" => "Porto Rico",
      "Costa Rica" => "Costa Rica",
      "Panama" => "Panamá",
      "Guatemala" => "Guatemala",
      "Honduras" => "Honduras",
      "El Salvador" => "El Salvador",
      "Nicaragua" => "Nicarágua",
      "Belize" => "Belize",
      "Guyana" => "Guiana",
      "Suriname" => "Suriname",
      "Bahamas" => "Bahamas",
      "Trinidad and Tobago" => "Trinidad e Tobago",
      "Falkland Is." => "Ilhas Malvinas",
      "Falkland Islands" => "Ilhas Malvinas",

      # Europa
      "France" => "França",
      "Germany" => "Alemanha",
      "Italy" => "Itália",
      "Spain" => "Espanha",
      "Portugal" => "Portugal",
      "United Kingdom" => "Reino Unido",
      "Russia" => "Rússia",
      "Greece" => "Grécia",
      "Poland" => "Polônia",
      "Netherlands" => "Holanda",
      "Belgium" => "Bélgica",
      "Switzerland" => "Suíça",
      "Austria" => "Áustria",
      "Sweden" => "Suécia",
      "Norway" => "Noruega",
      "Finland" => "Finlândia",
      "Denmark" => "Dinamarca",
      "Ireland" => "Irlanda",
      "Iceland" => "Islândia",
      "Ukraine" => "Ucrânia",
      "Czech Republic" => "República Tcheca",
      "Czechia" => "República Tcheca",
      "Hungary" => "Hungria",
      "Romania" => "Romênia",
      "Bulgaria" => "Bulgária",
      "Croatia" => "Croácia",
      "Serbia" => "Sérvia",
      "Slovenia" => "Eslovênia",
      "Slovakia" => "Eslováquia",
      "North Macedonia" => "Macedônia do Norte",
      "Albania" => "Albânia",
      "Montenegro" => "Montenegro",
      "Bosnia and Herzegovina" => "Bósnia e Herzegovina",
      "Bosnia and Herz." => "Bósnia e Herzegovina",
      "Kosovo" => "Kosovo",
      "Moldova" => "Moldávia",
      "Belarus" => "Bielorrússia",
      "Latvia" => "Letônia",
      "Lithuania" => "Lituânia",
      "Estonia" => "Estônia",
      "Luxembourg" => "Luxemburgo",
      "Cyprus" => "Chipre",
      "N. Cyprus" => "Chipre do Norte",

      # Ásia
      "China" => "China",
      "Japan" => "Japão",
      "South Korea" => "Coreia do Sul",
      "North Korea" => "Coreia do Norte",
      "India" => "Índia",
      "Indonesia" => "Indonésia",
      "Malaysia" => "Malásia",
      "Thailand" => "Tailândia",
      "Vietnam" => "Vietnã",
      "Philippines" => "Filipinas",
      "Singapore" => "Singapura",
      "Myanmar" => "Mianmar",
      "Cambodia" => "Camboja",
      "Laos" => "Laos",
      "Bangladesh" => "Bangladesh",
      "Nepal" => "Nepal",
      "Bhutan" => "Butão",
      "Sri Lanka" => "Sri Lanka",
      "Pakistan" => "Paquistão",
      "Afghanistan" => "Afeganistão",
      "Mongolia" => "Mongólia",
      "Kazakhstan" => "Cazaquistão",
      "Uzbekistan" => "Uzbequistão",
      "Turkmenistan" => "Turcomenistão",
      "Tajikistan" => "Tajiquistão",
      "Kyrgyzstan" => "Quirguistão",
      "Taiwan" => "Taiwan",
      "Brunei" => "Brunei",
      "Timor-Leste" => "Timor-Leste",

      # Oriente Médio
      "Saudi Arabia" => "Arábia Saudita",
      "United Arab Emirates" => "Emirados Árabes Unidos",
      "Israel" => "Israel",
      "Palestine" => "Palestina",
      "Iran" => "Irã",
      "Iraq" => "Iraque",
      "Turkey" => "Turquia",
      "Syria" => "Síria",
      "Jordan" => "Jordânia",
      "Lebanon" => "Líbano",
      "Kuwait" => "Kuwait",
      "Qatar" => "Catar",
      "Oman" => "Omã",
      "Yemen" => "Iêmen",
      "Armenia" => "Armênia",
      "Azerbaijan" => "Azerbaijão",
      "Georgia" => "Geórgia",

      # África
      "South Africa" => "África do Sul",
      "Egypt" => "Egito",
      "Nigeria" => "Nigéria",
      "Kenya" => "Quênia",
      "Morocco" => "Marrocos",
      "Algeria" => "Argélia",
      "Tunisia" => "Tunísia",
      "Libya" => "Líbia",
      "Sudan" => "Sudão",
      "S. Sudan" => "Sudão do Sul",
      "South Sudan" => "Sudão do Sul",
      "Ethiopia" => "Etiópia",
      "Tanzania" => "Tanzânia",
      "Democratic Republic of the Congo" => "República Democrática do Congo",
      "Dem. Rep. Congo" => "República Democrática do Congo",
      "Angola" => "Angola",
      "Mozambique" => "Moçambique",
      "Ghana" => "Gana",
      "Ivory Coast" => "Costa do Marfim",
      "Côte d'Ivoire" => "Costa do Marfim",
      "Senegal" => "Senegal",
      "Cameroon" => "Camarões",
      "Zimbabwe" => "Zimbábue",
      "Botswana" => "Botsuana",
      "Namibia" => "Namíbia",
      "Madagascar" => "Madagascar",
      "Mali" => "Mali",
      "Mauritania" => "Mauritânia",
      "Niger" => "Níger",
      "Chad" => "Chade",
      "Benin" => "Benim",
      "Togo" => "Togo",
      "Burkina Faso" => "Burkina Faso",
      "Guinea" => "Guiné",
      "Guinea-Bissau" => "Guiné-Bissau",
      "Liberia" => "Libéria",
      "Sierra Leone" => "Serra Leoa",
      "Gambia" => "Gâmbia",
      "Central African Rep." => "República Centro-Africana",
      "Central African Republic" => "República Centro-Africana",
      "Congo" => "Congo",
      "Republic of the Congo" => "República do Congo",
      "Gabon" => "Gabão",
      "Eq. Guinea" => "Guiné Equatorial",
      "Equatorial Guinea" => "Guiné Equatorial",
      "Zambia" => "Zâmbia",
      "Malawi" => "Malawi",
      "Lesotho" => "Lesoto",
      "eSwatini" => "Eswatini",
      "Eswatini" => "Eswatini",
      "Burundi" => "Burundi",
      "Rwanda" => "Ruanda",
      "Uganda" => "Uganda",
      "Somalia" => "Somália",
      "Somaliland" => "Somalilândia",
      "Eritrea" => "Eritreia",
      "Djibouti" => "Djibuti",
      "W. Sahara" => "Saara Ocidental",
      "Western Sahara" => "Saara Ocidental",

      # Oceania
      "Australia" => "Austrália",
      "New Zealand" => "Nova Zelândia",
      "Papua New Guinea" => "Papua Nova Guiné",
      "Fiji" => "Fiji",
      "Vanuatu" => "Vanuatu",
      "Solomon Is." => "Ilhas Salomão",
      "Solomon Islands" => "Ilhas Salomão",
      "New Caledonia" => "Nova Caledônia",

      # Outros
      "Greenland" => "Groenlândia",
      "Antarctica" => "Antártida",
      "Fr. S. Antarctic Lands" => "Terras Austrais Francesas"
    }

    # Dificuldade baseada em critérios:
    # - easy: países grandes e conhecidos
    # - medium: países médios ou menos conhecidos
    # - hard: países pequenos ou pouco conhecidos
    difficulty_mapping = {
      # Easy - países grandes e bem conhecidos
      "Brazil" => :easy,
      "Russia" => :easy,
      "United States of America" => :easy,
      "Canada" => :easy,
      "China" => :easy,
      "Australia" => :easy,
      "India" => :easy,
      "Argentina" => :easy,
      "Mexico" => :easy,
      "France" => :easy,
      "Germany" => :easy,
      "Japan" => :easy,
      "United Kingdom" => :easy,
      "Italy" => :easy,
      "Spain" => :easy,

      # Hard - países pequenos ou menos conhecidos
      "Tuvalu" => :hard,
      "Fiji" => :hard,
      "Vanuatu" => :hard,
      "Samoa" => :hard,
      "Tonga" => :hard,
      "Kiribati" => :hard,
      "Brunei" => :hard,
      "Bhutan" => :hard,
      "Lesotho" => :hard,
      "Eswatini" => :hard,
      "Djibouti" => :hard,
      "Burundi" => :hard,
      "Rwanda" => :hard,
      "Gambia" => :hard,
      "Guinea-Bissau" => :hard,
      "Equatorial Guinea" => :hard,
      "Gabon" => :hard,
      "Republic of the Congo" => :hard,
      "Central African Republic" => :hard,
      "South Sudan" => :hard,
      "Eritrea" => :hard,
      "Comoros" => :hard,
      "Mauritius" => :hard,
      "Seychelles" => :hard,
      "Maldives" => :hard,
      "Timor-Leste" => :hard,
      "Turkmenistan" => :hard,
      "Tajikistan" => :hard,
      "Kyrgyzstan" => :hard,
      "Armenia" => :hard,
      "Azerbaijan" => :hard,
      "Georgia" => :hard,
      "Moldova" => :hard,
      "Belarus" => :hard,
      "Latvia" => :hard,
      "Lithuania" => :hard,
      "Estonia" => :hard,
      "Slovenia" => :hard,
      "Slovakia" => :hard,
      "North Macedonia" => :hard,
      "Albania" => :hard,
      "Montenegro" => :hard,
      "Bosnia and Herzegovina" => :hard,
      "Kosovo" => :hard
    }

    imported = 0
    skipped = 0

    data["features"].each do |feature|
      properties = feature["properties"]
      geometry = feature["geometry"]

      # Pular se não tiver geometria válida
      unless geometry && %w[Polygon MultiPolygon].include?(geometry["type"])
        skipped += 1
        next
      end

      name = properties["NAME"] || properties["name"] || properties["ADMIN"]
      next unless name

      # Converter Polygon para MultiPolygon se necessário
      geojson = if geometry["type"] == "Polygon"
        { "type" => "MultiPolygon", "coordinates" => [ geometry["coordinates"] ] }
      else
        geometry
      end

      # Criar geometria PostGIS a partir do GeoJSON
      begin
        boundary_sql = "ST_SetSRID(ST_GeomFromGeoJSON('#{geojson.to_json}'), 4326)"

        country = Country.find_or_initialize_by(name: name)
        country.name_pt = portuguese_names[name] || name
        country.difficulty = difficulty_mapping[name] || :medium

        # Usar SQL direto para inserir a geometria
        if country.new_record?
          Country.connection.execute(<<~SQL)
            INSERT INTO countries (name, name_pt, difficulty, boundary, created_at, updated_at)
            VALUES (
              '#{name.gsub("'", "''")}',
              '#{country.name_pt.gsub("'", "''")}',
              #{Country.difficulties[country.difficulty]},
              #{boundary_sql},
              NOW(),
              NOW()
            )
          SQL
        else
          Country.connection.execute(<<~SQL)
            UPDATE countries
            SET boundary = #{boundary_sql},
                name_pt = '#{country.name_pt.gsub("'", "''")}',
                difficulty = #{Country.difficulties[country.difficulty]},
                updated_at = NOW()
            WHERE id = #{country.id}
          SQL
        end

        imported += 1
        print "." if imported % 10 == 0
      rescue => e
        puts "\nErro ao importar #{name}: #{e.message}"
        skipped += 1
      end
    end

    puts "\n\nImportação concluída!"
    puts "Importados: #{imported}"
    puts "Ignorados: #{skipped}"
    puts "Total no banco: #{Country.count}"
  end

  desc "Lista países no banco com estatísticas"
  task stats: :environment do
    puts "Estatísticas de países:"
    puts "-" * 40
    puts "Total: #{Country.count}"
    puts "Fácil: #{Country.easy.count}"
    puts "Médio: #{Country.medium.count}"
    puts "Difícil: #{Country.hard.count}"
    puts "-" * 40
    puts "\nExemplos por dificuldade:"
    puts "\nFácil:"
    Country.easy.limit(5).each { |c| puts "  - #{c.name_pt}" }
    puts "\nMédio:"
    Country.medium.limit(5).each { |c| puts "  - #{c.name_pt}" }
    puts "\nDifícil:"
    Country.hard.limit(5).each { |c| puts "  - #{c.name_pt}" }
  end
end
