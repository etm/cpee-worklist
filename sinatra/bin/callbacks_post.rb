id = request.env['HTTP_CPEE_CALLBACK']
id = id.scan( /\/([^\/]+)/)[1].first
result = {"url" => request.env['HTTP_CPEE_CALLBACK'], "form" => params[:form], "id" => id, "role" => params[:role], "text" => params[:text], "schaden" => params[:schaden]}
$callbacks[$callbacks.length] = result 
response.headers['CPEE_CALLBACK'] = 'true'
200
