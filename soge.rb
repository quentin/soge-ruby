require 'rubygems'
require 'hpricot'
require 'mechanize'

BASE="https://particuliers.secure.societegenerale.fr/"

CODECLI="123456" # identifiant client
PASS="123456" # mot de passe

agent = Mechanize.new

# recupere une description du clavier
page = agent.get(BASE + "cvcsgenclavier?mode=json&estSession=0")
vkdata = eval(page.body[page.body.index('{') .. page.body.index('}')].gsub(":","=>"))

# recupere l'image du clavier
content = agent.get_file(BASE + "cvcsgenimage?modeClavier=0&cryptogramme=#{vkdata['crypto']}")
file = File.new("tmp/keyboard.png","w+")
file.write(content)
file.close

# decoupe l'image du clavier en 16 cases
`convert -crop 24x23 tmp/keyboard.png tmp/tile_%d.png`

# trouve la correspondance case de l'image <=> numero
tile_file = Dir.glob("tmp/tile_*.png")
ref_file = Dir.glob("refs/*.png")
tiles = tile_file.inject({}) do |tiles, file|
  ref = ref_file.find do |ref| 
    `compare -metric mae #{file} #{ref} /dev/null 2>&1`.split.first.to_f == 0.0
  end
  
  if ref
    tiles[ref.scan(/[0-9]/).first.to_i] = file.scan(/[0-9]+/).first.to_i
    ref_file.delete(ref)
  end
  tiles
end

# verifie que tous les numeros ont ete detectes dans l'image
(0..9).each{|i| throw "#{i} not found" unless tiles.keys.include?(i)}

# construit la sequence de codes correspondant au mot de passe
codes = []
pass = PASS.scan(/./).map{|c| c.to_i}
pass.size.times do |i|
  codes << vkdata['grid'][tiles[pass[i]] + 16 * i]
end

# authentification: envoie la sequence de codes
postdata = {
  "codcli"=> CODECLI, 
  "versionCla"=> 0, 
  "cryptocvcs"=> vkdata['crypto'], 
  "codsec"=> codes.join(","), 
  'categNav'=> "W3C"}
page = agent.post(BASE + "acces/authlgn.html", postdata)

# extraction des couples numero/solde des comptes
# affiches sur la page principale
doc = Hpricot(page.body)
doc.search("tr[@class=LGNTableRow]").each do |row|
  num = (row/"td[@headers=NumeroCompte]").first.to_plain_text
  solde = (row/"td[@headers=Solde]").first.to_plain_text
  puts "#{num} #{solde}"
end

