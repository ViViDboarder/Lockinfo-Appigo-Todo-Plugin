function TodoPlugin()
{
}

TodoPlugin.prototype.bundleIdentifier="cx.ath.jakewalk.TodoPlugin";
TodoPlugin.prototype.updateView = function(todo) {

  var todos = todo.todos;

  if (todos.length > 0) {
	var html = "<ul><li class='header'>Todo" + 
	  ((todos.length==1) ? " " : "s ") + todo.preferences.List + "</li>";

	for (i = 0; i < todos.length; i++) {
	  html += "<li class='summary"+(i == 0 ? " firstItem" : "")+(i == todos.length - 1 ? " lastItem" : "")+"'>"+todos[i].text+"</li>";

	  if(todos[i].due) {
		var date = new Date();
		date.setTime((parseInt(todos[i].due)) * 1000);

		html += "<li class='location'>"+date.toLocaleDateString();

		/* flags: 1 = due time, 2 = has note, 3 = due time + has note */
		if ((todos[i].flags == 1) || (todos[i].flags == 3))		
			html += ", "+date.toLocaleTimeString().substr(0,5);	

		html += "</li>";
	  } else {
		html += "<li class='location'> </li>";
	  }
	}

	/*
	  for(var prop in todo)
	  html += "<li>" + prop + "</li>";
	*/

	html += "</ul>";
	getPluginDiv(this).className = "todo";
	getPluginDiv(this).innerHTML = html;
		
  } else {
  	getPluginDiv(this).innerHTML = "";
  }

  return true;
}

registerPlugin(new TodoPlugin());
