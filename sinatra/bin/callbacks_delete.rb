if $callbacks.any? { |c| c["id"] == id }
  $callbacks = $callbacks.reject { |c| id.include? c["id"] }
  200
else
  404
end
#idiomatisch: 
#$callbacks.length > $callbacks.delete_if{ |c| c["id"] == id } ? 200 : 404
