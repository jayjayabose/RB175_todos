require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"


=begin
Data Structure
  session[:lists] -> array (list hashes)
    list hash: {name: String, todos: Array (todo Hashes)}  
      todo hash; {name: String, completed: Boolean}
=end

# Return error message if name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    return "The list must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name}
    return "The list name \" #{name}\" is already in use."
  end
end

# Return error message if todo is invalid. Return nil if todo is valid
def error_for_todo(name)
  if !(1..100).cover? name.size
    return "The todo must be between 1 and 100 characters."
  end
end

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def list_complete?(list)
    todos_count(list) >= 1 && todos_not_completed_count(list) == 0
  end

  def list_class(list)
    "complete" if list_complete?(list)
  end

  def todos_not_completed_count(list)
    list[:todos].count { |todo| !todo[:completed] }
  end

  def todos_count(list)
    list[:todos].size
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list| list_complete?(list)}
    incomplete_lists.each { |list| yield list, lists.index(list)}
    complete_lists.each { |list| yield list, lists.index(list)}
    end

  def todo_class(todo)
    "complete" if todo[:completed]
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed]}
    incomplete_todos.each { |todo| yield todo, todos.index(todo)}
    complete_todos.each { |todo| yield todo, todos.index(todo)}
  end 
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View list of todo lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Display new todo list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

# View a single todo list
get "/lists/:id" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  erb :list, layout: :layout
end

# Handler: Create a new todo list
post "/lists" do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created."
    redirect "/lists"
  end
end

# Form: edit an existing todo list name
get "/lists/:id/edit" do
  list_id = params[:id].to_i
  @list = session[:lists][list_id]
  erb :edit_list, layout: :layout
end

# Handler: attempt to edit an existing todo list name. direct based on error or success
post "/lists/:id" do
  list_name = params[:list_name].strip
  list_id = params[:id].to_i
  @list = session[:lists][list_id]

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = "The list has been udpated."
    redirect "/lists/#{list_id}"
  end
end

# Handler: delete a todo list. redirect to /lists
post "/lists/:id/destroy" do
  list_id = params[:id].to_i
  @list = session[:lists].delete_at(list_id)
  session[:success] = "The list has been deleted."
  redirect "/lists"
end

# Handler: Add todo to an existing todo list
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  text = params[:todo].strip

  error = error_for_todo(text)
  if error
    session[:error] = error
    erb :list, layout: :layout
  else
    @list[:todos] << {name: text, completed: false}
    session[:success] = "The todo was added."
    redirect "/lists/#{@list_id}"
  end
end

# Handler: delete todo from todo list
post "/lists/:list_id/todos/:todo_id/destroy" do
  todo_id = params[:todo_id].to_i
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @list[:todos].delete_at(todo_id)
  redirect "/lists/#{@list_id}"
end

# Handler: Mark a todo completed
post "/lists/:list_id/todos/:todo_id/toggle_complete" do
  todo_id = params[:todo_id].to_i
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  @list[:todos][todo_id][:completed] = !@list[:todos][todo_id][:completed]
  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Handler: Mark all todos completed for a list
post "/lists/:id/complete_all" do
  @list_id = params[:id].to_i
  @list = session[:lists][@list_id]
  @list[:todos].each do |todo|
    todo[:completed] = true
  end
  session[:success] = "All todos have been completed."
  redirect "/lists/#{@list_id}"
end