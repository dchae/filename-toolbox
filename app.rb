require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'
require 'pdf-reader'

configure do
  enable :sessions
  set :session_secret, SecureRandom.hex(32)
  set :erb, escape_html: true
end

before do
  session[:messages] ||= []
  #
end

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
  extension = File.extname(filename).downcase
  extension == '.pdf'
end

get '/' do
  erb :index, layout: :layout
end

get '/extract/pdf' do
  erb :extract_pdf
end

def extract_from_pdf(file_path)
  reader = PDF::Reader.new(file_path)
  raw_text = reader.pages.map { |page| page.text }.join.split
  selected = raw_text.select { |s| s =~ /(Unit|\d\d\_\d\d)/}
  clean = selected.map { |filename| filenamebase(filename).gsub(/(\_[fx])+$/, '') }
end

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

      # see if I can do this without saving the file first
      File.open(session_file_path(filename), 'wb') { |f| f.write(file.read) }
      @clean = extract_from_pdf(session_file_path(filename))
    end
  end
  FileUtils.rm_rf(session_file_path)
  erb :extract_pdf
end

not_found do
  add_message 'File or page not found. Redirected to home.'
  redirect '/'
end
