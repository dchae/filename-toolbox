require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'pdf-reader'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, escape_html: true
end

before { session[:messages] ||= [] }

def add_message(msg)
  session[:messages] << msg
end

def file_path(filename = nil, subfolder = 'temp')
  if ENV['RACK_ENV'] == 'test'
    subfolder = 'test/' + subfolder
  else
    subfolder = '/' + subfolder
  end
  filename = File.basename(filename) if filename
  File.join(*[File.expand_path('..', __FILE__), subfolder, filename].compact)
end

def session_file_path(filename = nil)
  FileUtils.mkdir_p(file_path(nil, 'temp/' + session[:session_id]))
  file_path(filename, 'temp/' + session[:session_id])
end

def filenamebase(filename)
  File.basename(filename, '.*')
end

def valid_filetype_upload(filename)
  # Currently just checks that file extension is pdf
  extension = File.extname(filename).downcase
  extension == '.pdf'
end

# Extract from PDF text wrangler method
def extract_from_pdf(file_path)
  reader = PDF::Reader.new(file_path)
  raw_text = reader.pages.map { |page| page.text }.join.split
  selected = raw_text.select { |s| s =~ /(Unit|\d\d\_\d\d)/ }
  clean =
    selected.map { |filename| filenamebase(filename).gsub(/(\_[fx])+$/, '') }
end

# Render home
get '/' do
  erb :index, layout: :layout
end

# Render extract PDF page
get '/extract/pdf' do
  erb :extract_pdf
end

# Process uploaded PDF and render extracted results
post '/upload/pdf' do
  @clean = []

  if !params[:upload]
    add_message 'Unsupported filetype. Please upload a PDF'
  else
    filename = params[:upload][:filename]

    unless valid_filetype_upload(filename)
      add_message 'Unsupported filetype. Please upload a PDF'
    else
      file = params[:upload][:tempfile]

      # see if I can do this without saving the file first (just save to session?)
      File.open(session_file_path(filename), 'wb') { |f| f.write(file.read) }
      @clean = extract_from_pdf(session_file_path(filename))
      session[:clean] = @clean
    end
  end
  FileUtils.rm_rf(session_file_path)
  erb :extract_pdf
end

# Render compare page
get '/compare' do
  session[:list1] ||= session[:clean] || []
  session[:list2] ||= []
  erb :compare
end

post '/compare' do
  session[:list1] = params[:list1].split
  p session[:list2] = params[:list2].split

  # remove duplicates and add message if duplicates were removed
  list1_duplicates = session[:list1].tally.select { |k, v| v > 1 }
  list2_duplicates = session[:list2].tally.select { |k, v| v > 1 }
  if !list1_duplicates.empty?
    session[:list1].uniq!
    add_message "#{list1_duplicates.size} duplicate(s) were removed from A:\n#{list1_duplicates.keys}"
  end

  if !list2_duplicates.empty?
    session[:list2].uniq!
    add_message "#{list2_duplicates.size} duplicate(s) were removed from B"
  end

  # display the differences between the lists
  @missing_from_a = session[:list2] - session[:list1]
  @missing_from_b = session[:list1] - session[:list2]

  erb :compare
end

not_found do
  add_message 'File or page not found. Redirected to home.'
  redirect '/'
end
