module Cleaners

  def clean_zipcode(zip)
    zip.to_s.rjust(5,"0")[0..4]
  end

  def clean_phone(phone)
    cleaned = phone.gsub(/\D/,"")
    if cleaned.length == 10
      return cleaned
    elsif cleaned.length == 11 && cleaned[0] == "1"
      return cleaned[1..10]
    else
      return "0" * 10
    end
  end

end