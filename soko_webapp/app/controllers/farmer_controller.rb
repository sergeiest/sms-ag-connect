class FarmerController < ApplicationController

before_filter do
  if ENV['gmail'].blank? or ENV['gmailp'].blank?
    flash[:warning] = "The configuration variables \"gmail\" and \"gmailp\" are not set on the server. Creating a new ledger will not work.<br><br>Make sure you set these configuration variables and restart the server."
  end
end


def index

end

def send_web_sms
  redirect_to :action => "new_sms", :Body => params[:Body], :From => params[:From], :send_sms => 0
end


def new_sms

  if params[:From].nil? || params[:From].length < 1
    render :nothing => true and return
  end

  phone_number = params[:From].gsub(/[\(\)\-\s]/, '')

  if params[:Body].nil? || params[:Body].length < 1
    @response_text = send_help
  else
    sms_array = params[:Body].split("*")
    for i in 0..sms_array.length-1
      sms_array[i].strip!
    end

    case sms_array[0].downcase
      when "register"
        @response_text = add_user phone_number, sms_array
      when "inventory"
        @response_text = add_inventory phone_number, sms_array
      when "deal"
        @response_text = add_deal phone_number, sms_array
      when "history"
        @response_text = history_deal phone_number, sms_array
      when "buy"
        @response_text = buy_inventory phone_number, sms_array
      when "help"
        @response_text = send_help
      else
        @response_text = send_help
    end
  end



  if params[:send_sms].nil? || params[:send_sms] != '0'
    send_sms_twilio phone_number, @response_text
    render :nothing => true
  else
    render "index"
  end

end



def add_user phone_number, sms_array

  session = GoogleDrive.login(ENV['gmail'], ENV['gmailp'])
  spreadsheet = session.spreadsheet_by_title("testing_users")

  if spreadsheet.blank?
    spreadsheet = session.create_spreadsheet("testing_users")
    worksheet = spreadsheet.worksheets[0]
    worksheet[1,1] = "Time"
    worksheet[1,2] = "Phone Number"
    worksheet[1,3] = "Name"
    worksheet[1,4] = "Location"
    worksheet.save
  end

  worksheet = spreadsheet.worksheets[0]

  user_exist = 0
  for row in 1..worksheet.num_rows
    user_exist = row if worksheet[row, 2] == phone_number
  end

  if user_exist > 0
    worksheet[user_exist,1] = Time.now
    worksheet[user_exist,3] = sms_array[1]
    worksheet[user_exist,4] = sms_array[2]
    response_text = "Your info was updated. Name: " + sms_array[1] + " * Location: " + sms_array[2]
  else
    worksheet.list.push({"Time" => Time.now,
                         "Phone Number" => phone_number,
                         "Name" => sms_array[1],
                         "Location" => sms_array[2]
                        })
    response_text = "Your info was added to DB. Name: " + sms_array[1] + " * Location: " + sms_array[2]
  end

  worksheet.save
  return response_text

end


def add_inventory phone_number, sms_array
  session = GoogleDrive.login(ENV['gmail'], ENV['gmailp'])
  spreadsheet = session.spreadsheet_by_title("testing_inventory")

  if spreadsheet.blank?
    spreadsheet = session.create_spreadsheet("testing_inventory")
    worksheet = spreadsheet.worksheets[0]
    worksheet[1,1] = "Time"
    worksheet[1,2] = "Phone Number"
    worksheet[1,3] = "Product"
    worksheet[1,4] = "Quantity"
    worksheet[1,5] = "Date"
    worksheet.save
  end

  worksheet = spreadsheet.worksheets[0]
  worksheet.list.push({"Time" => Time.now,
                      "Phone Number" => phone_number,
                      "Product" => sms_array[1],
                      "Quantity" => sms_array[2],
                      "Date" => sms_array[3]
                      })
  worksheet.save

  response_text = "Your inventory was recorded."
  response_text += " Product: " + sms_array[1] if !sms_array[1].nil?
  response_text += " * Quantity: " + sms_array[2] if !sms_array[2].nil?
  response_text += " * Date: " + sms_array[3] if !sms_array[3].nil?

  return response_text

end

def add_deal phone_number, sms_array
  session = GoogleDrive.login(ENV['gmail'], ENV['gmailp'])
  spreadsheet = session.spreadsheet_by_title("testing_deal")

  if spreadsheet.blank?
    spreadsheet = session.create_spreadsheet("testing_deal")
    worksheet = spreadsheet.worksheets[0]
    worksheet[1,1] = "Time"
    worksheet[1,2] = "Phone Number"
    worksheet[1,3] = "Product"
    worksheet[1,4] = "Quantity"
    worksheet[1,5] = "Price"
    worksheet[1,6] = "Date of the deal"
    worksheet.save
  end

  worksheet = spreadsheet.worksheets[0]
  worksheet.list.push({"Time" => Time.now,
                       "Phone Number" => phone_number,
                       "Product" => sms_array[1],
                       "Quantity" => sms_array[2],
                       "Price" => sms_array[3],
                       "Date of the deal" => sms_array[4]
                      })
  worksheet.save

  response_text = "Your deal was recorded."
  response_text += " Product: " + sms_array[1] if !sms_array[1].nil?
  response_text += " * Quantity: " + sms_array[2] if !sms_array[2].nil?
  response_text += " * Price: " + sms_array[3] if !sms_array[3].nil?

  return response_text

end

def history_deal phone_number, sms_array
  session = GoogleDrive.login(ENV['gmail'], ENV['gmailp'])
  spreadsheet = session.spreadsheet_by_title("testing_deal")

  if spreadsheet.blank?
    response_text = "No deals were found for " + sms_array[1]
  else
    worksheet = spreadsheet.worksheets[0]

    response_text = ""
    for row in 1..worksheet.num_rows
      if worksheet[row, 3].strip.downcase == sms_array[1].downcase
        response_text += worksheet[row, 4] + ", " + worksheet[row, 5] + " * "
      end
    end

    if response_text == ""
      response_text = "No deals were found for " + sms_array[1] + " (possible reasons: spelling)"
    else
      response_text = "Deals with " + sms_array[1] + ": " + response_text[0..-4]
    end
  end

  return response_text

end



def buy_inventory phone_number, sms_array
  session = GoogleDrive.login(ENV['gmail'], ENV['gmailp'])
  spreadsheet_inventory = session.spreadsheet_by_title("testing_inventory")
  spreadsheet_users = session.spreadsheet_by_title("testing_users")

  return "No inventory were found for " + sms_array[1] if spreadsheet_inventory.blank? or spreadsheet_users.blank?

  worksheet_inventory = spreadsheet_inventory.worksheets[0]
  worksheet_users = spreadsheet_users.worksheets[0]

  in_locations = Array.new
  in_quantities = Array.new
  in_dates = Array.new

  all_locations = Array.new
  all_phones = Array.new

  for row in 1..worksheet_users.num_rows
    all_phones << worksheet_users[row, 2].strip
    all_locations << worksheet_users[row, 4].strip
  end

  for row in 1..worksheet_inventory.num_rows
    if worksheet_inventory[row, 3].strip.downcase == sms_array[1].downcase
      if all_phones.include?(worksheet_inventory[row, 2].strip)
        in_locations << all_locations[all_phones.index(worksheet_inventory[row, 2])]
      else
        in_locations << "no location"
      end
      in_quantities << worksheet_inventory[row, 4]
      in_dates << worksheet_inventory[row, 5]
    end
  end

  response_text = ""
  for i in 0..in_quantities.length - 1
    response_text += in_quantities[i] + ", " + in_dates[i] + ", " + in_locations[i] + " * "
  end

  if response_text == ""
    response_text = "No inventory were found for " + sms_array[1] + " (possible reasons: spelling)"
  else
    response_text = "Inventory for " + sms_array[1] + ": " + response_text[0..-4]
  end

  return response_text

end

def send_help
  response_text = "Help menu: start your text with the word 'register' to add a new user, ".html_safe +
                  " with 'inventory' to add info about an inventory, ".html_safe +
                  " with 'deal' to add info about a deal, ".html_safe +
                  " type 'help' to get the help menu. Split information with '*'(starts).".html_safe

  return response_text
end

def get_sms
  text_from_phone_no = params[:msisdn]
  text_body = params[:text]

  render :nothing => true
end

def send_sms phone_number, text
  nexmo = Nexmo::Client.new(ENV['nexmokey'], ENV['nexmosecret'])
  nexmo.http.verify_mode = OpenSSL::SSL::VERIFY_NONE

  nexmo.send_message!({from: '19802294810', to: phone_number, text: text[0..149]})
end

def send_sms_twilio phone_number, text

  client = Twilio::REST::Client.new(ENV['twiliosid'], ENV['twiliotoken'])

  account = client.account

  n = 0
  begin
    text_to_send = text[n..n+159]
    message = account.sms.messages.create({:from => '+15107303599', :to => phone_number, :body => text_to_send})
    puts message
    n += 160
  end while text.length > n and n < 320

end

end
