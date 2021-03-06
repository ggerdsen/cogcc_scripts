#!/Users/troyburke/.rvm/rubies/ruby-2.1.2/bin/ruby

# COGCC Facility Locations

# UNIX shell script to run scraper: while true; do ./facility_locations.rb & sleep 30; done

# Include required classes and models:

require '../import_data_config'

require 'rubygems'
require 'active_record'
require 'pg'
require 'mechanize'
require 'nokogiri'

# Include database table models:

mappings_directory = getMappings

require mappings_directory + 'counties'
require mappings_directory + 'facilities'


# begin error trapping
begin

  start_time = Time.now

  # Establish a database connection
  ActiveRecord::Base.establish_connection( { adapter: 'postgresql', host: getDBHost, port: getDBPort, username: getDBUsername, database: getDBDatabase, schema_search_path: getDBSchema } )

  # use random browser
  agent_aliases = [ 'Windows IE 7', 'Windows Mozilla', 'Mac Safari', 'Mac FireFox', 'Mac Mozilla', 'Linux Mozilla', 'Linux Firefox' ]
  agent_alias = agent_aliases[rand(0..6)]

  agent = Mechanize.new { |agent| agent.user_agent_alias = agent_alias }

  puts agent_alias

  page_url = "http://cogcc.state.co.us/cogis/FacilitySearch.asp"

  nbsp = Nokogiri::HTML("&nbsp;").text

  fac_type_id = 13

  Counties.find_by_sql("SELECT * FROM counties WHERE api_code <> '123' AND in_use IS FALSE AND location_scraped IS FALSE LIMIT 1").each do |c|

    puts c.api_code

    page = agent.get(page_url)

    search_form = page.form_with(name: 'cogims2')
    search_form.field_with(name: 'factype').value = "'LOCATION'"
    search_form.field_with(name: 'ApiCountyCode').value = "#{c.api_code}"
    search_form.field_with(name: 'maxrec').value = 10000
    search_results = search_form.submit

    page = agent.submit(search_form)

    # get http response code to check for valid url
    response = page.code.to_s

    # retreive body html
    doc = Nokogiri::HTML(page.body)

    results_table = doc.xpath('//table[2]')

    puts results_table

    results_table.css('tr').each_with_index do |tr,i|

      if i >= 2 then

        f = Facilities.new

        f.facility_type_id = fac_type_id

        f.facility_type = tr.xpath('td[1]').text.gsub(nbsp, " ").strip

        f.facility_detail_url = tr.xpath('td[1]').at('a')['href'].to_s

        f.facility_id = tr.xpath('td[2]').text.gsub(nbsp, " ").strip

        facility_cell = tr.xpath('td[3]')
        facility_cell.search('br').each do |n|
          n.replace("\n")
        end
        if !facility_cell.text.split("\n")[0].nil? then
          f.facility_name = facility_cell.text.split("\n")[0].gsub(nbsp, " ").strip
        end
        if !facility_cell.text.split("\n")[1].nil? then
          f.facility_number = facility_cell.text.split("\n")[1].gsub(nbsp, " ").strip
        end

        operator_cell = tr.xpath('td[4]')
        operator_cell.search('br').each do |n|
          n.replace("\n")
        end
        if !operator_cell.text.split("\n")[0].nil? then
          f.operator_name = operator_cell.text.split("\n")[0].gsub(nbsp, " ").strip
        end
        if !operator_cell.text.split("\n")[1].nil? then
          f.operator_number = operator_cell.text.split("\n")[1].gsub(nbsp, " ").strip
        end

        f.status_code = tr.xpath('td[5]').text.gsub(nbsp, " ").strip

        field_cell = tr.xpath('td[6]')
        field_cell.search('br').each do |n|
          n.replace("\n")
        end
        if !field_cell.text.split("\n")[0].nil? then
          f.field_name = field_cell.text.split("\n")[0].gsub(nbsp, " ").strip
        end
        if !field_cell.text.split("\n")[1].nil? then
          f.field_number = field_cell.text.split("\n")[1].gsub(nbsp, " ").strip
        end

        location_cell = tr.xpath('td[7]')
        location_cell.search('br').each do |n|
          n.replace("\n")
        end
        if !location_cell.text.split("\n")[0].nil? then
          f.location_county = location_cell.text.split("\n")[0].gsub(nbsp, " ").strip
        end
        if !location_cell.text.split("\n")[1].nil? then
          f.location_plss = location_cell.text.split("\n")[1].gsub(nbsp, " ").strip
        end

        f.related_facilities_url = tr.xpath('td[8]').at('a')['href'].to_s

        f.save!

      end # table row check

    end # table row loop

    c.location_scraped = true
    c.save!

  end # county loop

  puts "Time Start: #{start_time}"
  puts "Time End: #{Time.now}"

rescue Exception => e

  puts e.message

end


