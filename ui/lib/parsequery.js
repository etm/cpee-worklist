$.parseQuery = function(querystring) {
  var ret = [];
  querystring.replace(/#.*$/,'');
  querystring.replace(/([^&=]+)=?([^&]*)(?:&+|$)/g, function(match, key, value) {
    ret.push( { 'key': key, 'value': value  });
  });
  return ret;
}
