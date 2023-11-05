require 'sinatra'
require 'sinatra/reloader' if development?
require 'tilt/erubis'

configure do
  # enable :sessions
  # set :session_secret, SecureRandom.hex(32)
  set :erb, escape_html: true
end

before do
  session[:messages] ||= []
  #
end

def add_message(msg)
  session[:messages] << msg
end

get '/' do
  erb :index, layout: :layout
end

get '/extract/pdf' do
  erb :extract_pdf
end

post 'extract/pdf' do
  filename = params[:upload][:filename]
  unless valid_filetype_upload(filename)
    add_message 'Unsupported filetype. Please upload a PDF'
  else
    file = params[:upload][:tempfile]
  end
  erb :extract_pdf
end

not_found do
  add_message 'File or page not found. Redirected to home.'
  redirect '/'
end
