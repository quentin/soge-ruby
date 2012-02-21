module Bank
  
  class Identity
    attr_reader :name
    def initialize name
      @name = name
    end

    def to_s
      "Identity(#{name})"
    end
  end

  class Account
    attr_reader :identity, :name, :uid
    def initialize identity, name, uid
      @identity = identity
      @name = name
      @uid = uid
    end

    def to_s
      "Account(#{name})"
    end

    def default_currency
      "EUR"
    end

    def operations
      []
    end
  end

  class Operation
    attr_reader :account, :amount, :currency, :date, :uid
    
    def self.create account, date, amount, currency, uid
      klass = (amount < 0 ? DebitOperation : CreditOperation)
      return klass.new(account, date, amount, currency, uid)
    end

    def initialize account, date, amount, currency, uid
      @account = account
      @amount = amount
      @date = date
      @currency = currency
      @uid = uid
    end

    def to_s
      "Operation(#{date.strftime("%d/%m/%Y")} #{amount} #{currency} #{uid})"
    end
  end

  class CreditOperation < Operation
  end

  class DebitOperation < Operation
  end

end
