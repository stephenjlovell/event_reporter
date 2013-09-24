require 'csv'
require 'sunlight/congress'
require './lib/cleaners'
require 'table_print'



Attendee = Struct.new(:last_name, :first_name, :email, :zipcode,
                      :city, :state, :address, :phone_number, :legislators)

class EventReporter
  include Cleaners

  def initialize
    Sunlight::Congress.api_key = "e179a6973728c4dd3fb1204283aaccb5"
    @queue = []
    @data = []
  end

  def run
    puts "\nWelcome to EventReporter!\n-------------------------\n"
    command = ''
    while command != 'quit' && command != 'exit' && command != 'q'
      print "Enter a command: "
      command = gets.chomp
      route_command(command)
    end
  end

  def get_legislators_by_zip(zip)
    Sunlight::Congress::Legislator.by_zipcode(zip)
  end

  def get_legislator_names_by_zip(zip)
    legislators = get_legislators_by_zip(zip)
    legislators.collect {|leg| "#{leg.first_name} #{leg.last_name}"}
  end

  def invalid_command(command)
    puts "'#{command}' is not an Event Reporter command.  Run 'help' for a list of valid commands."
  end

  def route_command(command)
    args = command.split(" ")
    command = args.shift
    case command
    when 'load'
      load(args)
    when 'help'
      help(args)
    when 'queue'
      route_queue(args)  # using args.shift would simplify matters here...
    when 'find'
      find(args)
    when 'quit', 'exit', 'q'
      puts "Thanks for using EventReporter!"
    else 
      invalid_command(command)
    end
  end

  def load (args)
    if args.empty?
      filename = 'event_attendees.csv' # default
    else
      filename = args[0]
    end

    begin
      contents = CSV.open filename, headers: true, header_converters: :symbol
    rescue
      puts "Unable to read from file #{filename}.  Make sure this is a valid path to a CSV file."
      return
    end
    # fields:  id,RegDate,first_Name,last_Name,Email_Address,HomePhone,Street,City,State,Zipcode
    # legislators fields: FIRST_NAME, LAST_NAME, WEBSITE

    @data = [] # clear out any old data.
    puts "loading file: #{filename}"

    contents.each do |row|
      zip = clean_zipcode(row[:zipcode])
      phone = clean_phone(row[:homephone])
      
      legislators = get_legislator_names_by_zip(zip).join(", ")

      record = Attendee.new(row[:last_name],row[:first_name], row[:email_address], zip, 
                            row[:city], row[:state], row[:street], phone, legislators)
      @data.push(record)
    end
    print_records_as_table(@data)
  end

  def help(args)
    help_hash = { 'load <filename>' => 'Erases any loaded data and parse the specified file. If no filename is given, defaults to event_attendees.csv.',
      'help' => 'Outputs a listing of the available individual commands.',
      'help <command>' => 'Outputs a description of how to use the specific command.',
      'queue count' => 'Gives the total number of records in the queue.',
      'queue clear' => 'Removes all records from the queue.',
      'queue print' => 'Prints out a tab-delimited data table containing all records in the queue',
      'queue print by <attribute>' => 'Prints the data table sorted by the specified attribute like zipcode.',
      'queue save to <filename.csv>' => 'Exports the current queue to the specified filename as a CSV. The file should should include data and headers for last name, first name, email, zipcode, city, state, address, and phone number.',
      'find <attribute> <criteria>' => 'Loads all records matching the criteria for the given attribute into the queue.', 
      'exit' => "Exits EventReporter. You may also use 'quit' or 'q' to exit." }
    
    command = args.join(" ")
    if help_hash[command]
      puts "#{command} : #{help_hash[command]}"
    else
      puts "\nThe following commands are available:\n\n"
      help_hash.each { |key, value| puts "#{key} : #{value}\n\n" }
    end
  end

  def route_queue(args)
    command = args.shift
    case command
    when 'count'
      count_queue
    when 'clear'
      clear_queue
    when 'print'
      print_queue(args)
    when 'save'
      save_queue(args)
    else
      invalid_command("queue #{command}")
    end
  end

  def count_queue
    puts "#{@queue.length} records in queue."
  end

  def clear_queue
    @queue = []
    puts "all records cleared from queue."
  end


  def print_queue(args)
    if @queue.empty?
      puts "No items in queue.  Use find to load items into queue."
    elsif args.empty?
      print_records_as_table(@queue)
    else
      command = args.shift
      if command == 'by'
        print_queue_by(args)
        # 'queue print by <attribute>' => 'Prints the data table sorted by the specified attribute like zipcode.',
      else
        invalid_command("queue print #{command}")
      end
    end
  end

  def print_queue_by(args)
    if args.empty?
      print_records_as_table(@queue)
    else
      command = args.shift.to_sym
      if @queue.first.respond_to?(command)
        @queue.sort! { |a,b| a[command] <=> b[command] }
        print_records_as_table(@queue)
      else
        invalid_command("queue print by #{command.to_s}")
      end
    end
  end

  def print_records_as_table(obj)
    puts "\n"
    tp obj, :last_name, :first_name, :email, :zipcode,
            :city, :state, :phone_number, {legislators: {width: 80}}
    puts "\n"
  end

  def save_queue(args)
    command = args.shift
    if command == 'to'
      save_queue_to(args[0])
    else
      invalid_command("queue save #{command}")
    end
  end

  def save_queue_to(filename)
    # 'queue save to <filename.csv>' => 'Exports the current queue to the specified filename as a CSV. 
    # The file should should include data and headers for last name, first name, email, zipcode, city, state, 
    # address, and phone number.'
    puts "saving contents of queue to #{filename}"
  end

  def find(args)
    # 'find <attribute> <criteria>' => 'Loads all records matching the criteria for the given attribute into the queue.' } 
    if @data.empty?
      puts "no data currently loaded. use load <filename> to load a data file."
    elsif args.empty?
      find_all
    else
      attribute = args.shift.to_sym
      if @data.first.respond_to?(attribute)
        find_by(attribute, args)
      else
        invalid_command("find #{attribute.to_s}")
      end
    end
  end

  def find_by(attribute, args)
    if args.empty?
      find_all
    else
      criteria = args.join(" ").downcase
      results = @data.select { |d| d[attribute].downcase == criteria } 
      if results.empty?
        puts "no records found with #{attribute.to_s} matching criteria #{criteria}"
      else
        results.each { |r| @queue.push(r) }
      end
    end
  end

  def find_all
    print "add all #{@data.length} data records to queue? (y/n): "
    response = gets.chomp.downcase
    if response == "y" || response == "yes"
      @queue = []
      @data.each { |d| @queue.push(d) }
      puts "all data records loaded into queue."
    end
  end

end

er = EventReporter.new
er.run

#------ methods to implement:











