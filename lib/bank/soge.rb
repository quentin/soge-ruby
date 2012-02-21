require 'rubygems'
require 'mechanize'
require 'hpricot'
require 'iconv'
require 'csv'
require 'digest'

module Bank
  module SocieteGenerale
    BASE="https://particuliers.secure.societegenerale.fr"

    class Identite < Bank::Identity
      def initialize client_code, client_password, name = nil
        super(name || client_code.to_s)
        @connection = Connection.new(client_code, client_password)
      end

      def get_page url
        Hpricot(get_body(url))
      end

      def get_body url
        @connection.get_page(url).body
      end

      def accounts
        prestations = get_page(BASE + "/restitution/cns_listeprestation.html")
        accs = []
        
        (prestations/"tr[@class~=LGNTableRow]").each do |tr|
          numero = (tr/"td[@headers=NumeroCompte]").first.inner_text.gsub(/\302\240/,' ')
          solde = (tr/"td[@headers=Solde]").first.inner_text.gsub(/\302\240/,' ')
          type = (tr/"td[@headers=TypeCompte]/a").first
          lien = type.attributes['href']
          type = type.inner_text

          accs << Compte.create(self, type, numero, lien)
        end
        accs
      end
    end

    class Compte < Bank::Account
      attr_reader :number
      TYPE_TO_CLASS = {
        Iconv.conv("LATIN1","UTF-8","Compte Bancaire") => :CompteBancaire,
        Iconv.conv("LATIN1","UTF-8","Carte Bleue Visa") => :CompteVisa,
        Iconv.conv("LATIN1","UTF-8","Livret A") => :CompteLivretA,
        Iconv.conv("LATIN1","UTF-8","Livret Dévelop. Durable") => :CompteLDD,
      }

      def self.create identity, type, number, link
        klass = SocieteGenerale.const_get(TYPE_TO_CLASS[type])
        klass.new(identity, number, link)
      end

      def initialize identity, number, link
        super(identity, self.class.name.to_s + number.to_s, number.tr(" ",""))
        @number = number
        @link = link
        @solde = nil
        @currency = nil
      end

      def solde
        0.0
      end

      def currency
        "N/A"
      end
    end

    class CompteBancaire < Compte
      def operations
        update if @operations.nil?
        @operations
      end

      def operations!
        update
        @operations
      end

      def solde
        update if @solde == nil
        @solde
      end

      def solde!
        update
        @solde
      end

      def currency
        update if @currency == nil
        @currency
      end

      def currency!
        update
        @currency
      end

      def update
        list = []

        @operations = nil
        @solde = nil
        @currency = nil

        operations = identity.get_page(BASE + "/restitution/tel_telechargement.html")
        option = (operations/"select[@id=compte]/option").find do |opt|
          text = opt.inner_text.gsub(/\302\240/," ")
          opt['value'] && text.include?(@number)
        end

        if option
          crypto = option['value']
          url = BASE + "/restitution/tel_fichiers/#{@number[0]}.csv?"
          url += "#{crypto}"
          url += "&numcpt=#{@number.tr(' ','')}"
          url += "&logiciel=CSV&periode=XXJOURS&datedu=00000000&dateau=00000000"
          url += "&typefich=CSV&nbcompte=1"
          lines = identity.get_body(url).split("\r\n")

          sld = lines.shift.split(";").last
          @solde = sld.scan(/[+-]?[0-9\.,]+/).first.gsub(',','.').to_f
          #@solde = sld.split.first.to_f
          @currency = sld.split.last

          lines.shift
          lines.shift

          rownum = 0
          lastdate = [nil,0] # date and index of the last operation
          lines.each do |line|
            row = CSV.parse_line(line,';')
            lastdate[1] += 1
            lastdate = [row[0],0] unless lastdate[0] == row[0]
            
            # compute operation unique ID based on 
            # - account unique ID
            # - operation date
            # - operation index for the operation date
            ouid = Digest::SHA1.hexdigest("#{uid}-#{lastdate.join('-')}")

            date = DateTime.civil(*(row[0].split("/").reverse.map{|cell| cell.to_i}))
            amount = row[3].tr(',','.').to_f

            list << Operation.new(self, date, amount, row[4], ouid) 
            rownum+=1
          end
        end

        @operations = list
      end
    end

    class CompteVisa < Compte
    end

    class CompteLivretA < Compte
      def solde
        update if @solde == nil
        @solde
      end
      def currency
        update if @currency == nil
        @currency
      end
      def update
        @solde = nil
        consultation = identity.get_page(BASE + @link)
        sld = (consultation/"td[@headers=solde1]").inner_text.gsub(/[\302\240\s]/,'')
        @solde = sld.scan(/[+-]?[0-9\.,]+/).first.gsub(',','.').to_f
        @currency = sld.scan(/[A-Z]+/).first
      end
    end

    class CompteLDD < CompteLivretA
    end

    class Connection
      def initialize client_code, client_password
        @client_code = client_code.to_s
        @client_password = client_password.to_s
        @agent = nil
        @debug = false
      end

      def debug msg
        return unless @debug
        STDERR.puts msg
        nil
      end

      def reconnect
        @agent = Mechanize.new

        # recupere une description du clavier
        debug "fetching virtual keyboard url"
        page = @agent.get(BASE + "/cvcsgenclavier?mode=json&estSession=0")
        vkdata = eval(page.body[page.body.index('{') .. page.body.index('}')].gsub(":","=>"))

        # recupere l'image du clavier
        debug "fetching virtual keyboard picture"
        content = @agent.get_file(BASE + "/cvcsgenimage?modeClavier=0&cryptogramme=#{vkdata['crypto']}")
        file = File.new("tmp/keyboard.png","w+")
        file.write(content)
        file.close

        # decoupe l'image du clavier en 16 cases
        debug "tiling virtual keyboard picture"
        `convert -crop 24x23 tmp/keyboard.png tmp/tile_%d.png`

        # trouve la correspondance case de l'image <=> numero
        debug "processing tiles identification"
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
        debug "building password codes sequence"
        codes = []
        pass = @client_password.scan(/./).map{|c| c.to_i}
        pass.size.times do |i|
          codes << vkdata['grid'][tiles[pass[i]] + 16 * i]
        end

        # authentification: envoie la sequence de codes
        debug "sending password codes sequence"
        postdata = {
          "codcli"=> @client_code, 
          "versionCla"=> 0, 
          "cryptocvcs"=> vkdata['crypto'], 
          "codsec"=> codes.join(","), 
          'categNav'=> "W3C"}
        page = @agent.post(BASE + "/acces/authlgn.html", postdata)
        
        debug "identification done"
        nil
      rescue => e
        debug "identification failed"
        @agent = nil
        raise e
      end

      def get_page(url)
        debug "fetching page `#{url}`"
        reconnect if @agent.nil?
        return @agent.get(url)
      end
    end
  end
end
