require 'csv'
require 'sunlight/congress'
require 'table/print'

Sunlight::Congress.api_key = "e179a6973728c4dd3fb1204283aaccb5"

# puts "Event Manager Initialized"

def clean_zipcode(zip)
  zip.to_s.rjust(5,"0")[0..4]
end

def get_legislators_by_zip(zip)
  Sunlight::Congress::Legislator.by_zipcode(zip)
end

# def save_form_letter(id, form_letter)
#   Dir.mkdir("output") unless Dir.exists?("output")

#   filename = "output/thanks_#{id}.html"

#   File.open(filename,'w') do |file|
#     file.puts form_letter
#   end
# end

# template = File.read 'form_letter.erb'
# erb_template = ERB.new template
contents = CSV.open 'event_attendees.csv', headers: true, header_converters: :symbol

contents.each do |row|
  id = row[0]
  name = row[:first_name]
  zip = clean_zipcode(row[:zipcode])
  legislators = get_legislators_by_zip(zip)
  form_letter = erb_template.result(binding)
  save_form_letter(id, form_letter)
end

